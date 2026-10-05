// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SystemPackage

func package(_ path: FilePath, force: Bool, move: Bool) async throws {
  let source = try ScriptSource(reading: .file(path))
  let shebang = source.text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
    .first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines)
  guard
    force
      || [
        "#!/usr/bin/swift sh", "#!/usr/bin/env swift sh", "#!/usr/bin/swift-sh", "#!/sbin/swift sh",
        "#!/bin/swift sh",
      ].contains(shebang ?? "")
  else { throw PackageError.notScript }
  let analysis = try ScriptAnalysis(source: source)
  let name = source.name.capitalized
  let destination = path.removingLastComponent().appending(name)
  let temporary = try TemporaryDirectory(parent: path.removingLastComponent())
  let toolchain = try await SwiftToolchain.discover(cache: BuildCache())
  try await toolchain.run(
    ["package", "init", "--type", "executable", "--name", name, "--disable-swift-testing"],
    in: temporary.path)
  let sources = temporary.path.appending("Sources").appending(name)
  for file in try FileManager.default.contentsOfDirectory(
    at: fileURL(sources), includingPropertiesForKeys: nil) where file.pathExtension == "swift"
  {
    try FileManager.default.removeItem(at: file)
  }
  try source.compilableText.write(
    to: fileURL(sources.appending(analysis.hasMainAttribute ? name + ".swift" : "main.swift")),
    atomically: true, encoding: .utf8)
  var seen: Set<String> = []
  for dependency in analysis.dependencies {
    if seen.insert(dependency.packageLine).inserted {
      let arguments: [String]
      switch dependency.dependencyName {
      case .local: arguments = ["--type", "path"]
      case .remote: arguments = dependency.constraint.packageArguments
      }
      try await toolchain.run(
        ["package", "add-dependency", dependency.dependencyName.location] + arguments,
        in: temporary.path)
    }
    try await toolchain.run(
      [
        "package", "add-target-dependency", dependency.importName, name, "--package",
        dependency.dependencyName.identity,
      ], in: temporary.path)
  }
  if move {
    let backup = temporary.path.appending("original-script")
    try FileManager.default.moveItem(at: fileURL(path), to: fileURL(backup))
    do {
      try FileManager.default.moveItem(at: fileURL(temporary.path), to: fileURL(destination))
    } catch {
      try FileManager.default.moveItem(at: fileURL(backup), to: fileURL(path))
      throw error
    }
    try FileManager.default.removeItem(at: fileURL(destination.appending("original-script")))
  } else {
    try FileManager.default.moveItem(at: fileURL(temporary.path), to: fileURL(destination))
  }
  print("created: \(destination)")
}

enum PackageError: LocalizedError {
  case notScript

  var errorDescription: String? { "cannot package; not Swift script (override with --force)" }
}
