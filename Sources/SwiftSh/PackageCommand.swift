// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import ArgumentParser
import Foundation
import SystemPackage

struct PackageCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "package",
    abstract: "Create a SwiftPM package from a swift-sh script.")

  static let shebangs: Set<String> = [
    "#!/usr/bin/swift sh", "#!/usr/bin/env swift sh", "#!/usr/bin/swift-sh",
    "#!/usr/bin/env swift-sh", "#!/sbin/swift sh", "#!/bin/swift sh",
  ]

  @Argument(help: "The script to package.")
  var script: String

  @Flag(help: "Package the file even if it does not have a swift-sh shebang.")
  var force = false

  @Flag(help: "Move the script into the generated package instead of copying it.")
  var move = false

  func run() async throws {
    let path = absolutePath(script)
    let source = try ScriptSource(reading: .file(path))
    let shebang = source.text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
      .first.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard force || Self.shebangs.contains(shebang ?? "") else {
      throw PackageError.missingShebang(path.string)
    }
    let analysis = try ScriptAnalysis(source: source)
    let name = source.name.capitalized
    let parent = path.removingLastComponent()
    let destination = parent.appending(name)
    let temporary = try TemporaryDirectory(parent: parent)
    let toolchain = try await SwiftToolchain.discover(cache: ScriptCache())
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
    var added: Set<String> = []
    for directive in analysis.dependencies {
      if added.insert(directive.source.location).inserted {
        try await toolchain.run(
          ["package", "add-dependency", directive.source.location]
            + (try await Self.requirementArguments(for: directive.source)),
          in: temporary.path)
      }
      try await toolchain.run(
        [
          "package", "add-target-dependency", directive.module, name, "--package",
          directive.source.identity,
        ], in: temporary.path)
    }
    if move {
      let original = temporary.path.appending("original-script")
      try FileManager.default.moveItem(at: fileURL(path), to: fileURL(original))
      do {
        try FileManager.default.moveItem(at: fileURL(temporary.path), to: fileURL(destination))
      } catch {
        try FileManager.default.moveItem(at: fileURL(original), to: fileURL(path))
        throw error
      }
      try FileManager.default.removeItem(at: fileURL(destination.appending("original-script")))
    } else {
      try FileManager.default.moveItem(at: fileURL(temporary.path), to: fileURL(destination))
    }
    print("created: \(destination)")
  }

  /// A versionless import gets the newest release as its lower bound.
  static func requirementArguments(for source: DependencyDirective.Source) async throws -> [String]
  {
    switch source {
    case .local: return ["--type", "path"]
    case .remote(_, .upToNextMajor(let version)): return ["--from", version.description]
    case .remote(_, .exact(let version)): return ["--exact", version.description]
    case .remote(_, .revision(let reference)): return ["--revision", reference]
    case .remote(let url, .unspecified):
      return ["--from", try await ReleaseSelection.newestRelease(at: url).description]
    }
  }
}

enum PackageError: LocalizedError {
  case missingShebang(String)

  var errorDescription: String? {
    switch self {
    case .missingShebang(let path):
      return "\(path) does not start with a swift-sh shebang; use --force to package it anyway."
    }
  }
}
