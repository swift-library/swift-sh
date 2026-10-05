// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SystemPackage
import Testing

@testable import SwiftSh

struct ToolchainAndBuildTests {
  @Test func discoveryVerifiesTheVersionOnce() async throws {
    let temporary = try TemporaryDirectory()
    let bin = temporary.path.appending("bin")
    let swift = try fakeSwift(in: bin, body: "echo 'Swift version 6.3.1 (swift-6.3.1-RELEASE)'")
    let cache = ScriptCache(root: temporary.path.appending("cache"))
    let toolchain = try await SwiftToolchain.discover(
      cache: cache, environment: ["PATH": bin.string])
    #expect(toolchain.executable == swift)
    let declaration = cache.root.appending("toolchains/\(toolchain.fingerprint).json")
    #expect(try String(contentsOf: fileURL(declaration), encoding: .utf8) == "\"6.3.1\"")
  }

  @Test func discoveryRejectsOldToolchains() async throws {
    let temporary = try TemporaryDirectory()
    let bin = temporary.path.appending("bin")
    _ = try fakeSwift(in: bin, body: "echo 'Apple Swift version 6.2.3'")
    await #expect(throws: ToolchainError.self) {
      try await SwiftToolchain.discover(
        cache: ScriptCache(root: temporary.path.appending("cache")),
        environment: ["PATH": bin.string])
    }
  }

  @Test func fingerprintFollowsExecutableAndEnvironment() throws {
    let temporary = try TemporaryDirectory()
    let swift = try fakeSwift(in: temporary.path, body: "exit 0")
    let original = try SwiftToolchain.fingerprint(of: swift, environment: [:])
    #expect(
      try SwiftToolchain.fingerprint(of: swift, environment: ["PATH": "/elsewhere"]) == original)
    for variable in SwiftToolchain.selectingVariables {
      #expect(
        try SwiftToolchain.fingerprint(of: swift, environment: [variable: "changed"]) != original)
    }
    try "#!/bin/sh\nexit 1\n".write(to: fileURL(swift), atomically: true, encoding: .utf8)
    #expect(try SwiftToolchain.fingerprint(of: swift, environment: [:]) != original)
  }

  @Test func buildRecordsDecideWhenToRebuild() async throws {
    let temporary = try TemporaryDirectory()
    let log = temporary.path.appending("builds.log")
    let swift = try fakeSwift(
      in: temporary.path.appending("bin"),
      body: """
        echo "$*" >> '\(log.string)'
        configuration=debug
        while [ $# -gt 0 ]; do
          [ "$1" = --configuration ] && configuration=$2
          shift
        done
        mkdir -p .build/$configuration
        printf '#!/bin/sh\\n' > .build/$configuration/Script
        chmod +x .build/$configuration/Script
        """)
    let source = ScriptSource(
      path: nil, name: "Script", text: "print(1)\n", dependencyDirectory: temporary.path)
    var package = ScriptPackage(
      analysis: try ScriptAnalysis(source: source),
      cache: ScriptCache(root: temporary.path.appending("cache")))
    func builds() throws -> [String] {
      guard FileManager.default.fileExists(atPath: log.string) else { return [] }
      return try String(contentsOf: fileURL(log), encoding: .utf8)
        .split(separator: "\n").map(String.init)
    }

    try await package.build(using: SwiftToolchain(executable: swift, fingerprint: "a"))
    try await package.build(using: SwiftToolchain(executable: swift, fingerprint: "a"))
    #expect(try builds() == ["build --configuration release"])

    try await package.build(using: SwiftToolchain(executable: swift, fingerprint: "b"))
    #expect(try builds().count == 2)

    package.configuration = .debug
    try await package.build(using: SwiftToolchain(executable: swift, fingerprint: "b"))
    package.configuration = .release
    try await package.build(using: SwiftToolchain(executable: swift, fingerprint: "b"))
    #expect(try builds().last == "build --configuration debug")
    #expect(try builds().count == 3)

    try FileManager.default.removeItem(at: fileURL(package.binary))
    try await package.build(using: SwiftToolchain(executable: swift, fingerprint: "b"))
    #expect(try builds().count == 4)
  }

  @Test func editorLaunches() async throws {
    let temporary = try TemporaryDirectory()
    let source = ScriptSource(
      path: nil, name: "Script", text: "print(1)\n", dependencyDirectory: temporary.path)
    let package = ScriptPackage(
      analysis: try ScriptAnalysis(source: source),
      cache: ScriptCache(root: temporary.path.appending("cache")))
    #if os(macOS)
      #expect(
        try await EditorLaunch(for: package, xcode: true, environment: [:])
          == EditorLaunch(
            executable: "/usr/bin/open", arguments: ["-a", "Xcode", package.directory.string]))
    #else
      await #expect(throws: OpenError.self) {
        try await EditorLaunch(for: package, xcode: true, environment: [:])
      }
    #endif
    #expect(
      try await EditorLaunch(for: package, xcode: false, environment: ["EDITOR": "/bin/cat"])
        == EditorLaunch(
          executable: "/bin/cat", arguments: [package.entry.string],
          workingDirectory: package.directory))
    await #expect(throws: OpenError.self) {
      try await EditorLaunch(for: package, xcode: false, environment: [:])
    }
  }

  private func fakeSwift(in directory: FilePath, body: String) throws -> FilePath {
    try FileManager.default.createDirectory(
      at: fileURL(directory), withIntermediateDirectories: true)
    let path = directory.appending("swift")
    try "#!/bin/sh\n\(body)\n".write(to: fileURL(path), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.string)
    return path
  }
}
