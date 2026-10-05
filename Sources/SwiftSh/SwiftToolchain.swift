// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SemVer
import Subprocess
import SystemPackage

/// The `swift` executable that builds scripts, identified by a fingerprint that changes when the
/// toolchain or its selecting environment changes.
struct SwiftToolchain: Sendable {
  let executable: FilePath
  let fingerprint: String

  static let minimumVersion = Version(6, 3, 0)
  static let selectingVariables = [
    "SDKROOT", "DEVELOPER_DIR", "TOOLCHAINS", "MACOSX_DEPLOYMENT_TARGET",
  ]

  /// Finds `swift` in `PATH`, verifying its version once per fingerprint.
  static func discover(
    cache: ScriptCache, environment: [String: String] = ProcessInfo.processInfo.environment
  ) async throws -> SwiftToolchain {
    let lookup = Environment.custom(
      Dictionary(
        uniqueKeysWithValues: environment.map { (Environment.Key(stringLiteral: $0.key), $0.value) }
      ))
    var executable = FilePath(
      try await Executable.name("swift").resolveExecutablePath(in: lookup).string)
    #if os(macOS)
      if executable.string == "/usr/bin/swift" {
        let resolved = try await Subprocess.run(
          .name("xcrun"), arguments: ["--find", "swift"], output: .string(limit: 16_384),
          error: .string(limit: 16_384))
        guard resolved.terminationStatus.isSuccess else {
          throw ToolchainError.failed("xcrun", resolved.terminationStatus)
        }
        executable = FilePath(
          resolved.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))
      }
    #endif
    let fingerprint = try fingerprint(of: executable, environment: environment)
    let declaration = cache.root.appending("toolchains").appending(fingerprint + ".json")
    if let data = try? Data(contentsOf: fileURL(declaration)),
      let version = try? JSONDecoder().decode(String.self, from: data),
      let parsed = Version(lenient: version), parsed >= minimumVersion
    {
      return SwiftToolchain(executable: executable, fingerprint: fingerprint)
    }
    let result = try await Subprocess.run(
      .path(.init(executable.string)), arguments: ["--version"], output: .string(limit: 16_384),
      error: .string(limit: 16_384))
    guard result.terminationStatus.isSuccess else {
      throw ToolchainError.failed(executable.string, result.terminationStatus)
    }
    let words = result.standardOutput.split(whereSeparator: \.isWhitespace)
    guard let index = words.firstIndex(of: "version"), index + 1 < words.count,
      let version = Version(lenient: String(words[index + 1])),
      version >= minimumVersion
    else {
      throw ToolchainError.minimumVersion(result.standardOutput)
    }
    try FileManager.default.createDirectory(
      at: fileURL(declaration.removingLastComponent()), withIntermediateDirectories: true)
    try JSONEncoder().encode(version.description).write(to: fileURL(declaration), options: .atomic)
    return SwiftToolchain(executable: executable, fingerprint: fingerprint)
  }

  static func fingerprint(of executable: FilePath, environment: [String: String]) throws -> String {
    let attributes = try FileManager.default.attributesOfItem(atPath: executable.string)
    let modified = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    let identity =
      [
        executable.string, String(modified), String(describing: attributes[.size]),
        String(describing: attributes[.systemNumber]),
        String(describing: attributes[.systemFileNumber]),
        ProcessInfo.processInfo.operatingSystemVersionString,
      ] + selectingVariables.map { environment[$0] ?? "" }
    return digest(identity.joined(separator: "\u{0}"))
  }

  /// SwiftPM owns builds; its complete logs go directly to stderr without intermediate pipes.
  func run(_ arguments: [String], in directory: FilePath) async throws {
    let result = try await Subprocess.run(
      .path(.init(executable.string)), arguments: Arguments(arguments),
      workingDirectory: .init(directory.string),
      output: .currentStandardError, error: .currentStandardError)
    guard result.terminationStatus.isSuccess else {
      throw ToolchainError.failed(executable.string, result.terminationStatus)
    }
  }
}

enum ToolchainError: LocalizedError {
  case minimumVersion(String)
  case failed(String, TerminationStatus)

  var errorDescription: String? {
    switch self {
    case .minimumVersion(let output):
      return
        "Swift 6.3 or newer is required. Detected: \(output.trimmingCharacters(in: .whitespacesAndNewlines))"
    case .failed(let executable, let status): return "\(executable) failed: \(status)"
    }
  }
}
