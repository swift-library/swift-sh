// SPDX-License-Identifier: Unlicense

import Foundation
import Subprocess
import SystemPackage
import Testing

@testable import Sh

@Suite(.serialized, .timeLimit(.minutes(2)))
struct CommandIntegrationTests {
  @Test func versionHelpAndUsageExits() async throws {
    let fixture = try await CommandFixture()
    let version = try await fixture.invoke(["--version"])
    #expect(version.status == .exited(0))
    #expect(version.stdout == releaseVersion + "\n")
    #expect(version.stderr.isEmpty)
    let help = try await fixture.invoke(["--help"])
    #expect(help.status == .exited(0))
    #expect(help.stdout.contains("--version"))
    let error = try await fixture.invoke(["package", "--unknown"])
    #expect(error.status == .exited(3))
    #expect(error.stderr.contains("invalid usage"))
  }

  @Test func argumentsInputAndWorkingDirectory() async throws {
    let fixture = try await CommandFixture()
    let path = try fixture.script(
      "import Foundation\nprint(CommandLine.arguments.dropFirst().joined(separator: \"|\"))\nprint(readLine()!)\nprint(FileManager.default.currentDirectoryPath)\n"
    )
    let result = try await fixture.invoke(
      [path.string, "--version", "value with spaces"], input: "hello\n")
    #expect(result.status == .exited(0))
    let lines = result.stdout.split(separator: "\n").map(String.init)
    #expect(lines.count == 3)
    #expect(Array(lines.prefix(2)) == ["--version|value with spaces", "hello"])
    let directory = try #require(lines.last)
    let actual = try FileManager.default.attributesOfItem(atPath: directory)
    let expected = try FileManager.default.attributesOfItem(atPath: fixture.directory.string)
    #expect(actual[.systemNumber] as? NSNumber == expected[.systemNumber] as? NSNumber)
    #expect(actual[.systemFileNumber] as? NSNumber == expected[.systemFileNumber] as? NSNumber)
  }

  @Test func streamingAndConcurrentInputs() async throws {
    let fixture = try await CommandFixture()
    async let first = fixture.invoke(
      ["-", "--version"], input: "print(CommandLine.arguments[1])\n")
    async let second = fixture.invoke(["--"], input: "print(\"second\")\n")
    let results = try await (first, second)
    #expect(results.0.status == .exited(0))
    #expect(results.1.status == .exited(0))
    #expect(results.0.stdout == "--version\n")
    #expect(results.1.stdout == "second\n")
  }

  @Test func entrySwitchingAndCacheReuse() async throws {
    let fixture = try await CommandFixture()
    let path = try fixture.script("print(\"first\")\n")
    let first = try await fixture.invoke([path.string])
    #expect(first.stdout == "first\n")
    let hot = try await fixture.invoke([path.string])
    #expect(hot.stdout == "first\n")
    #expect(!hot.stderr.contains("Building"))
    try
      "#!/usr/bin/swift sh\n@main struct Program { static func main() { print(\"#!literal\") } }\n"
      .write(to: fileURL(path), atomically: true, encoding: .utf8)
    let attributed = try await fixture.invoke([path.string])
    #expect(attributed.status == .exited(0))
    #expect(attributed.stdout == "#!literal\n")
    let source = try ScriptSource(reading: .file(path))
    let generated = fixture.cache.directory(for: source)
    #expect(!FileManager.default.fileExists(atPath: generated.appending("main.swift").string))
    try "print(\"third\")\n".write(to: fileURL(path), atomically: true, encoding: .utf8)
    let topLevel = try await fixture.invoke([path.string])
    #expect(topLevel.status == .exited(0))
    #expect(topLevel.stdout == "third\n")
    #expect(!FileManager.default.fileExists(atPath: generated.appending("Root.swift").string))
  }

  @Test func concurrentRunsOfOneFile() async throws {
    let fixture = try await CommandFixture()
    let path = try fixture.script("print(42)\n")
    async let first = fixture.invoke([path.string])
    async let second = fixture.invoke([path.string])
    let results = try await (first, second)
    #expect(results.0.status == .exited(0))
    #expect(results.1.status == .exited(0))
    #expect(results.0.stdout == "42\n")
    #expect(results.1.stdout == "42\n")
  }

  @Test func sameNamesAndSpecificCleaning() async throws {
    let fixture = try await CommandFixture()
    let first = try fixture.script("print(1)\n", name: "one/hello.swift")
    let second = try fixture.script("print(2)\n", name: "two/hello.swift")
    #expect(try await fixture.invoke([first.string]).stdout == "1\n")
    #expect(try await fixture.invoke([second.string]).stdout == "2\n")
    let firstCache = fixture.cache.directory(for: try ScriptSource(reading: .file(first)))
    let secondCache = fixture.cache.directory(for: try ScriptSource(reading: .file(second)))
    #expect(firstCache != secondCache)
    #expect(try await fixture.invoke(["cache", "clean", first.string]).status == .exited(0))
    #expect(!FileManager.default.fileExists(atPath: firstCache.string))
    #expect(FileManager.default.fileExists(atPath: secondCache.string))
    #expect(try await fixture.invoke(["cache", "clean"]).status == .exited(0))
    #expect(!FileManager.default.fileExists(atPath: fixture.cache.root.string))
  }

  @Test func localDependencyAndRebuild() async throws {
    let fixture = try await CommandFixture()
    let dependency = try fixture.library()
    let script = try fixture.script("@testable import Fixture // ./dependency\nprint(value())\n")
    #expect(try await fixture.invoke([script.string]).stdout == "1\n")
    try "public func value() -> Int { 2 }\n".write(
      to: fileURL(dependency.appending("Sources/Fixture/Fixture.swift")), atomically: true,
      encoding: .utf8)
    #expect(try await fixture.invoke([script.string]).stdout == "2\n")
  }

  @Test func generatedCopiesProtectUserSource() throws {
    let temporary = try TemporaryDirectory()
    let path = temporary.path.appending("source.swift")
    let text = "print(1)\n"
    try text.write(to: fileURL(path), atomically: true, encoding: .utf8)
    let source = try ScriptSource(reading: .file(path))
    let script = Script(
      analysis: try ScriptAnalysis(source: source),
      cache: BuildCache(root: temporary.path.appending("cache")))
    try FileManager.default.createDirectory(
      at: fileURL(script.directory), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      atPath: script.entry.string, withDestinationPath: path.string)
    try script.write()
    try "generated modification\n".write(
      to: fileURL(script.entry), atomically: true, encoding: .utf8)
    #expect(try String(contentsOf: fileURL(path), encoding: .utf8) == text)
  }

  @Test(.timeLimit(.minutes(2))) func largeOutputAndFinalStatus() async throws {
    let fixture = try await CommandFixture()
    let path = try fixture.script(
      """
      import Foundation
      let data = Data(repeating: 65, count: 1_048_576)
      try FileHandle.standardOutput.write(contentsOf: data)
      try FileHandle.standardError.write(contentsOf: data)
      print("tail")
      exit(7)
      """)
    let result = try await fixture.invoke([path.string])
    #expect(result.status == .exited(7))
    #expect(result.stdout.utf8.count == 1_048_581)
    #expect(result.stdout.hasSuffix("tail\n"))
    #expect(result.stderr.hasSuffix(String(repeating: "A", count: 1_048_576)))
    let signaled = try fixture.script(
      """
      #if os(Linux)
      import Glibc
      #else
      import Darwin
      #endif
      raise(SIGTERM)
      """, name: "signal.swift")
    let signaledResult = try await fixture.invoke([signaled.string])
    #expect(signaledResult.status == .signaled(15), "\(signaledResult.stderr)")
  }

  @Test func buildFailurePreservesDiagnosticLine() async throws {
    let fixture = try await CommandFixture()
    let path = try fixture.script(
      "#!/usr/bin/swift sh\n@main struct Program {\n  static func main() { unknownSymbol() }\n}\n")
    let result = try await fixture.invoke([path.string])
    #expect(result.status == .exited(2))
    #expect(result.stderr.contains("Root.swift:3:"))
    #expect(result.stderr.contains("unknownSymbol"))
    let invalid = fixture.directory.appending("invalid.swift")
    try Data([0xFF]).write(to: fileURL(invalid))
    #expect(try await fixture.invoke([invalid.string]).status == .exited(2))
  }

  @Test(arguments: [false, true])
  func packageCopyMoveAndRun(move: Bool) async throws {
    let fixture = try await CommandFixture()
    let path = try fixture.script(
      "#!/usr/bin/swift sh\n@main struct Program { static func main() { print(3) } }\n",
      name: "foo.swift")
    let result = try await fixture.invoke(["package", path.string] + (move ? ["--move"] : []))
    #expect(result.status == .exited(0))
    #expect(FileManager.default.fileExists(atPath: path.string) == !move)
    let generated = fixture.directory.appending("Foo")
    let run = try await Subprocess.run(
      .name("swift"), arguments: ["run"], workingDirectory: .init(generated.string),
      output: .string(limit: 1_048_576), error: .string(limit: 1_048_576))
    #expect(run.terminationStatus.isSuccess)
    #expect(run.standardOutput == "3\n")
  }

  @Test func packagingFailureRestoresOriginal() async throws {
    let fixture = try await CommandFixture()
    let path = try fixture.script("#!/usr/bin/swift sh\nprint(1)\n", name: "foo.swift")
    let occupied = fixture.directory.appending("Foo")
    try FileManager.default.createDirectory(
      at: fileURL(occupied), withIntermediateDirectories: true)
    let result = try await fixture.invoke(["package", path.string, "--move"])
    #expect(result.status == .exited(2))
    #expect(
      try String(contentsOf: fileURL(path), encoding: .utf8) == "#!/usr/bin/swift sh\nprint(1)\n")
  }

  @Test func packageForceAndFilenameClash() async throws {
    let fixture = try await CommandFixture()
    let plain = try fixture.script("print(8)\n", name: "plain.swift")
    #expect(try await fixture.invoke(["package", plain.string]).status == .exited(2))
    #expect(try await fixture.invoke(["package", plain.string, "--force"]).status == .exited(0))
    let clash = try fixture.script("#!/usr/bin/swift sh\nprint(9)\n", name: "foo")
    #expect(try await fixture.invoke(["package", clash.string, "--move"]).status == .exited(0))
    #expect(
      FileManager.default.fileExists(
        atPath: fixture.directory.appending("Foo/Package.swift").string))
  }

  @Test func editorAndNamedPipe() async throws {
    let fixture = try await CommandFixture()
    let path = try fixture.script("print(1)\n")
    let opened = try await fixture.invoke(
      ["open", path.string], environment: ["EDITOR": "/bin/cat"])
    #expect(opened.status == .exited(0))
    #expect(opened.stdout == "print(1)\n")
    #expect(
      try await fixture.invoke(
        ["open", path.string], environment: ["EDITOR": "missing-swift-sh-editor"]
      ).status == .exited(2))
    let substituted = try await Subprocess.run(
      .path("/bin/bash"),
      arguments: ["-c", "\"$1\" <(printf 'print(42)')", "bash", fixture.binary.string],
      environment: .inherit.updating(["XDG_CACHE_HOME": fixture.cacheParent.string]),
      workingDirectory: .init(fixture.directory.string), output: .string(limit: 1_048_576),
      error: .string(limit: 1_048_576))
    #expect(substituted.terminationStatus.isSuccess)
    #expect(substituted.standardOutput == "42\n")
  }
}

private struct CommandFixture: Sendable {
  let temporary: TemporaryDirectory
  let binary: FilePath
  var directory: FilePath { temporary.path }
  var cacheParent: FilePath { directory.appending("cache") }
  var cache: BuildCache { BuildCache(root: cacheParent.appending("swift-sh")) }

  init() async throws {
    temporary = try TemporaryDirectory()
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    binary = FilePath(
      ProcessInfo.processInfo.environment["SWIFT_SH_TEST_BINARY"]
        ?? root.appendingPathComponent(".build/debug/swift-sh").path)
    try #require(FileManager.default.isExecutableFile(atPath: binary.string))
  }

  func invoke(_ arguments: [String], input: String = "", environment: [String: String] = [:])
    async throws -> (stdout: String, stderr: String, status: TerminationStatus)
  {
    var variables = Dictionary(
      uniqueKeysWithValues: environment.map {
        (Environment.Key(stringLiteral: $0.key), Optional($0.value))
      })
    variables["XDG_CACHE_HOME"] = cacheParent.string
    let result = try await Subprocess.run(
      .path(.init(binary.string)), arguments: Arguments(arguments),
      environment: .inherit.updating(variables), workingDirectory: .init(directory.string),
      input: .string(input), output: .string(limit: 4_194_304), error: .string(limit: 4_194_304))
    return (result.standardOutput, result.standardError, result.terminationStatus)
  }

  func script(_ text: String, name: String = "hello.swift") throws -> FilePath {
    let path = directory.appending(name)
    try FileManager.default.createDirectory(
      at: fileURL(path.removingLastComponent()), withIntermediateDirectories: true)
    try text.write(to: fileURL(path), atomically: true, encoding: .utf8)
    return path
  }

  func library() throws -> FilePath {
    let root = directory.appending("dependency")
    try FileManager.default.createDirectory(
      at: fileURL(root.appending("Sources/Fixture")), withIntermediateDirectories: true)
    try """
    // swift-tools-version:6.3
    import PackageDescription
    let package = Package(name: "Fixture", products: [.library(name: "Fixture", targets: ["Fixture"])], targets: [.target(name: "Fixture")])
    """.write(to: fileURL(root.appending("Package.swift")), atomically: true, encoding: .utf8)
    try "public func value() -> Int { 1 }\n".write(
      to: fileURL(root.appending("Sources/Fixture/Fixture.swift")), atomically: true,
      encoding: .utf8)
    return root
  }
}
