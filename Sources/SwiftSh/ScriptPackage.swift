// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SemVer
import SystemPackage

enum BuildConfiguration: String, Sendable {
  case debug
  case release
}

/// The generated SwiftPM package that builds one script.
struct ScriptPackage {
  let analysis: ScriptAnalysis
  let cache: ScriptCache
  var configuration = BuildConfiguration.release

  var directory: FilePath { cache.directory(for: analysis.source) }
  var entryName: String { analysis.hasMainAttribute ? "Root.swift" : "main.swift" }
  var entry: FilePath { directory.appending(entryName) }
  var binary: FilePath {
    directory.appending(".build").appending(configuration.rawValue).appending(analysis.source.name)
  }

  /// Release modules compile for testing only when the script needs `@testable` access.
  var buildArguments: [String] {
    var arguments = ["build", "--configuration", configuration.rawValue]
    if configuration == .release && analysis.hasTestableImports {
      arguments += ["-Xswiftc", "-enable-testing"]
    }
    return arguments
  }

  /// The record of releases selected for versionless imports. Cleaning the cache selects again.
  var releaseRecord: FilePath { directory.appending(".release-selection.json") }

  /// Returns the recorded release for each versionless import, selecting missing ones once.
  func selectReleases() async throws -> [String: Version] {
    var releases =
      (try? Data(contentsOf: fileURL(releaseRecord))).flatMap {
        try? JSONDecoder().decode([String: Version].self, from: $0)
      } ?? [:]
    var selected = false
    for directive in analysis.dependencies {
      guard case .remote(let url, .unspecified) = directive.source, releases[url] == nil else {
        continue
      }
      releases[url] = try await ReleaseSelection.newestRelease(at: url)
      selected = true
    }
    if selected {
      try FileManager.default.createDirectory(
        at: fileURL(directory), withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(releases).write(to: fileURL(releaseRecord), options: .atomic)
    }
    return releases
  }

  func manifest(releases: [String: Version]) throws -> PackageManifest {
    #if os(macOS)
      let version = ProcessInfo.processInfo.operatingSystemVersion
      let deploymentTarget: String? = "\(version.majorVersion).\(version.minorVersion)"
    #else
      let deploymentTarget: String? = nil
    #endif
    return PackageManifest(
      name: analysis.source.name,
      targetName: "SwiftShScript_" + cache.key(for: analysis.source).prefix(16),
      entryFile: entryName,
      dependencies: try analysis.dependencies.map { try $0.manifestDependency(releases: releases) }
        .uniqued(),
      products: analysis.dependencies.map(\.manifestProduct).uniqued(),
      macOSDeploymentTarget: deploymentTarget)
  }

  /// Generated files are owned copies; changes never write through a link to user source.
  @discardableResult
  func write() async throws -> PackageManifest {
    let buildPaths =
      [directory.string, analysis.source.name]
      + analysis.dependencies.compactMap { directive -> String? in
        guard case .local(let path) = directive.source else { return nil }
        return path.string
      }
    if let path = buildPaths.first(where: {
      $0.unicodeScalars.contains { $0.value < 32 || $0.value == 34 || $0.value == 92 }
    }) {
      throw SourceError.unsupportedSwiftPMPath(path)
    }
    let manager = FileManager.default
    try manager.createDirectory(at: fileURL(directory), withIntermediateDirectories: true)
    let obsolete = directory.appending(analysis.hasMainAttribute ? "main.swift" : "Root.swift")
    if (try? manager.attributesOfItem(atPath: obsolete.string)) != nil {
      try manager.removeItem(at: fileURL(obsolete))
    }
    if (try? manager.attributesOfItem(atPath: entry.string)[.type] as? FileAttributeType)
      == .typeSymbolicLink
    {
      try manager.removeItem(at: fileURL(entry))
    }
    let manifest = try manifest(releases: try await selectReleases())
    try writeIfChanged(analysis.source.compilableText, to: entry)
    try writeIfChanged(manifest.rendered(), to: directory.appending("Package.swift"))
    return manifest
  }

  func build(using toolchain: SwiftToolchain) async throws {
    let manifest = try await write()
    let receipt = directory.appending(".build-record-\(configuration.rawValue).json")
    let expected = BuildRecord(
      arguments: buildArguments,
      source: digest(analysis.source.compilableText), manifest: digest(manifest.rendered()),
      toolchain: toolchain.fingerprint, localDependencies: try localDependencyFingerprint())
    let previous = (try? Data(contentsOf: fileURL(receipt))).flatMap {
      try? JSONDecoder().decode(BuildRecord.self, from: $0)
    }
    guard previous != expected || !FileManager.default.isExecutableFile(atPath: binary.string)
    else { return }
    try await toolchain.run(buildArguments, in: directory)
    try JSONEncoder().encode(expected).write(to: fileURL(receipt), options: .atomic)
  }

  private func localDependencyFingerprint() throws -> String {
    try contentDigest(
      of: analysis.dependencies.compactMap { directive in
        guard case .local(let path) = directive.source else { return nil }
        return path
      })
  }
}

private struct BuildRecord: Codable, Equatable {
  let arguments: [String]
  let source: String
  let manifest: String
  let toolchain: String
  let localDependencies: String
}

private func writeIfChanged(_ text: String, to path: FilePath) throws {
  guard (try? String(contentsOf: fileURL(path), encoding: .utf8)) != text else { return }
  try text.write(to: fileURL(path), atomically: true, encoding: .utf8)
}

extension Array where Element: Equatable {
  /// The elements in their original order without later duplicates.
  fileprivate func uniqued() -> [Element] {
    reduce(into: []) { result, element in
      if !result.contains(element) { result.append(element) }
    }
  }
}
