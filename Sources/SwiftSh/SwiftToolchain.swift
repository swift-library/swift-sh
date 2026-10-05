// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SemVer
import Subprocess
import SystemPackage

struct SwiftToolchain: Sendable {
  let executable: FilePath
  let fingerprint: String

  static func discover(cache: ScriptCache) async throws -> SwiftToolchain {
    let resolvedExecutable = try await Executable.name("swift").resolveExecutablePath(in: .inherit)
    var executable = FilePath(resolvedExecutable.string)
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
    let attributes = try FileManager.default.attributesOfItem(atPath: executable.string)
    let environment = ProcessInfo.processInfo.environment
    let identity =
      [
        executable.string, String(describing: attributes[.modificationDate]),
        String(describing: attributes[.size]),
        ProcessInfo.processInfo.operatingSystemVersionString,
      ]
      + ["SDKROOT", "DEVELOPER_DIR", "TOOLCHAINS", "MACOSX_DEPLOYMENT_TARGET"].map {
        environment[$0] ?? ""
      }
    let fingerprint = digest(identity.joined(separator: "\u{0}"))
    let declaration = cache.root.appending("toolchains").appending(fingerprint + ".json")
    if let data = try? Data(contentsOf: fileURL(declaration)),
      let version = try? JSONDecoder().decode(String.self, from: data),
      let parsed = Version(lenient: version), parsed >= Version(6, 3, 0)
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
      version >= Version(6, 3, 0)
    else {
      throw ToolchainError.minimumVersion(result.standardOutput)
    }
    try FileManager.default.createDirectory(
      at: fileURL(declaration.removingLastComponent()), withIntermediateDirectories: true)
    try JSONEncoder().encode(version.description).write(to: fileURL(declaration), options: .atomic)
    return SwiftToolchain(executable: executable, fingerprint: fingerprint)
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
