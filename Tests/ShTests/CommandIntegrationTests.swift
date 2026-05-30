import Foundation
import Path
import StreamReader
import Testing

@testable import Sh

@Suite(.serialized)
struct RunCommandIntegrationTests {
  init() {
    guard Path.build.isDirectory else { return }
    for entry in Path.build.ls()
    where entry.type == .directory
      && DynamicPath(entry).path.basename().hasPrefix(scriptBaseName)
    {
      try? DynamicPath(entry).path.delete()
    }
  }

  @Test func testConventional() {
    expectOutput(.resultScriptOutput, exec: .resultScript)
  }

  @Test func testNamingMismatch() {
    expectOutput(
      "/",
      exec: """
        import Path  // mxcl/Path.swift ~> 0.15

        print(Path.root)
        """)
  }

  @Test func testTestableImport() {
    expectOutput(
      "1.2.3",
      exec: """
        import Foundation
        @testable import Version  // @mxcl ~> 1.0

        print(Version(1,2,3))
        """)
  }

  @Test func testTestableFullySpecifiedURL() {
    expectOutput(
      "2.3.4",
      exec: """
        import Foundation
        @testable import Version  // https://github.com/mxcl/Version ~> 1.0

        print(Version(2,3,4))
        """)
  }

  @Test func testTestableExactVersion() {
    expectOutput(
      "3.4.5",
      exec: """
        import Foundation
        @testable import Version  // mxcl/Version == 1.0.2

        print(Version(3,4,5))
        """)
  }

  @Test func testTestableExactRevision() {
    expectOutput(
      ".success(5)",
      exec: """
        import Foundation
        @testable import Result  // antitypical/Result == 67613b45

        print(Result<Int, CocoaError>.success(5))
        """)
  }

  @Test func testTestableLatest() {
    expectOutput(
      "7.8.9",
      exec: """
        import Version  // @mxcl

        print(Version(7,8,9))
        """)
  }

  @Test func testUseLocalDependencyWithAbsolutePath() throws {
    let tmpdir = try Path.cwd.join("local_dep").mkdir()
    defer { _ = try? FileManager.default.removeItem(at: tmpdir.url) }

    let task = Process(arg0: "/bin/bash")
    task.currentDirectoryPath = tmpdir.string
    task.arguments = ["-c", "swift package init"]
    let stdout = Pipe()
    task.standardOutput = stdout
    try task.go()
    task.waitUntilExit()

    expectRuns(
      exec: """
        import local_dep  // \(tmpdir.string)
        """)
  }

  @Test func testUseLocalDependencyWithRelativePath() throws {
    let depName = "local_dep"
    let tmpDir = try Path.cwd.join(depName).mkdir()
    defer { _ = try? FileManager.default.removeItem(at: tmpDir.url) }

    // Use a dir under cwd because mkdir fails inside Path.mktemp
    let testDir = try Path.cwd.join("tempTestDir").mkdir()
    defer { _ = try? FileManager.default.removeItem(at: testDir.url) }

    // Place the local_dep inside cwd/local_dep
    let task = Process(arg0: "/bin/bash")
    task.currentDirectoryPath = tmpDir.string
    task.arguments = ["-c", "swift package init"]
    let stdout = Pipe()
    task.standardOutput = stdout
    try task.go()
    task.waitUntilExit()

    // Place the script inside cwd/tempTestDir
    // Provide "../local_dep" as the relative path to local_dep.
    //
    // We specifically use a different directory than cwd
    // to test that the script's provided relative path for local_dep
    // is relative to the script's path and not relative to the current working directory.
    expectRuns(
      exec: """
           import local_dep  // ../\(depName)
        """, path: testDir)
  }

  @Test func testStandardInputCanBeUsedInScript() throws {
    let stdin = Pipe()
    let stdout = Pipe()
    let hello = "Hello\n".data(using: .utf8)!

    try write(script: "print(readLine()!)") { file in
      let task = Process(arg0: file)
      task.standardInput = stdin
      task.standardOutput = stdout

      task.launchPath = file.string
      try task.go()

      stdin.fileHandleForWriting.write(hello)
      task.waitUntilExit()

      expectEqual(task.terminationReason, .exit)
      expectEqual(task.terminationStatus, 0)

      let got = stdout.fileHandleForReading.readDataToEndOfFile()

      expectEqual(got, hello)
    }
  }

  @Test func testStandardInputCanBeUsedBySwiftSh() throws {
    let stdin = Pipe()
    let stdout = Pipe()
    let task = Process(arg0: shebang)
    task.standardInput = stdin
    task.standardOutput = stdout
    try task.go()

    stdin.fileHandleForWriting.write("print(\"\(#function)\")".data(using: .utf8)!)
    stdin.fileHandleForWriting.closeFile()
    task.waitUntilExit()

    expectEqual(task.terminationReason, .exit)
    expectEqual(task.terminationStatus, 0)

    let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    expectEqual(out, "\(#function)\n")
  }

  @Test func testStandardInputCanBeUsedBySwiftShWithArgument() throws {
    let stdin = Pipe()
    let stdout = Pipe()
    let task = Process(arg0: shebang)
    task.arguments = ["foobar"]
    task.standardInput = stdin
    task.standardOutput = stdout
    try task.go()

    stdin.fileHandleForWriting.write("print(CommandLine.arguments[1])".data(using: .utf8)!)
    stdin.fileHandleForWriting.closeFile()
    task.waitUntilExit()

    expectEqual(task.terminationReason, .exit)
    expectEqual(task.terminationStatus, 0)

    let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    expectEqual(out, "foobar\n")
  }

  @Test func testProcessSubstitution() throws {
    try write(script: "print(\"\(#function)\")") { script in
      let task = Process(arg0: "/bin/bash")
      task.arguments = [
        "-c", "\(shebang) <(cat \"\(script)\")",
      ]
      let stdout = try task.runSync(.stdout).string
      expectEqual(stdout, #function)
    }
  }

  @Test func testProcessSubstitutionWithArgument() throws {
    try write(script: "print(CommandLine.arguments[1])") { script in
      let task = Process(arg0: "/bin/bash")
      task.arguments = [
        "-c", "\(shebang) <(cat \"\(script)\") \"\(#function)\"",
      ]
      let stdout = try task.runSync(.stdout).string
      expectEqual(stdout, #function)
    }
  }

  @Test func testArguments() {
    expectOutput(
      ".success(3)",
      exec: """
        import Foundation
        @testable import Result  // https://github.com/antitypical/Result ~> 4.1

        let arg = CommandLine.arguments[1]
        print(Result<Int, CocoaError>.success(Int(arg)!))
        """, arg: "3")
  }

  @Test func testSwiftMarkdownExample() throws {
    let path = Path(DynamicPath(Path(#filePath)!.parent.parent.parent).Examples.markdown)
    let code = try StreamReader(path: path).dropFirst().joined(separator: "\n")
    expectRuns(exec: code)
  }

  @Test func testAsyncMainCountLinesExample() throws {
    let path = Path(#filePath)!.parent.parent.parent / "Examples" / "async-main-count-lines"
    let code = try StreamReader(path: path).dropFirst().joined(separator: "\n")

    try Path.mktemp { tmpdir in
      let input = tmpdir / "input.txt"
      try "one\ntwo\nthree\n".write(to: input)
      expectOutput("3", exec: code, arg: input.string)
    }
  }

  @Test func testRelativePath() throws {
    try write(script: "print(123)") { file in
      let task = Process(arg0: file)
      task.launchPath = "/bin/sh"
      task.arguments = ["-c", "./\(file.basename())"]
      task.currentDirectoryPath = file.parent.string
      let stdout = try task.runSync(.stdout).string?.chuzzled()
      expectEqual(stdout, "123")
    }
  }

  @Test func testCWD() throws {
    let cwd = FileManager.default.currentDirectoryPath
    let script = """
      import Foundation
      print(FileManager.default.currentDirectoryPath)
      """
    expectOutput(cwd, exec: script)
  }

  @Test func testStdinScriptChangesAreSeen() throws {
    func go(input: String, line: UInt = #line) throws -> String? {
      let stdin = Pipe()
      let stdout = Pipe()
      let task = Process(arg0: shebang)
      task.standardInput = stdin
      task.standardOutput = stdout
      try task.go()

      stdin.fileHandleForWriting.write(input.data(using: .utf8)!)
      stdin.fileHandleForWriting.closeFile()
      task.waitUntilExit()

      expectEqual(task.terminationReason, .exit, line: line)
      expectEqual(task.terminationStatus, 0, line: line)

      expectEqual(
        try String(contentsOf: Path.build / "StandardInput/main.swift"), input, line: line)

      return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
    for x in 1...3 {
      expectEqual(try go(input: "print(\(x))"), "\(x)\n")

      #if swift(>=5)
      #else
        // sleep or race condition bug in SwiftPM 4.2 causes these tests to fail
        sleep(1)
      #endif
    }
  }

  @Test func testTwoScriptsSameNameWork() throws {
    // In the same temporary directory we create two directories each
    // containig a script of the same name but slightly different bodies.
    // If swift-sh cache is not disambiguating based on full path the
    // the second script will not be built and we will see the output of
    // the first when executing the second.
    try Path.mktemp { tmpdir -> Void in

      func create(script: String, inSubDir: String) throws -> Path {
        let scriptDir: Path = try tmpdir.join(inSubDir).mkdir()
        let file = scriptDir.join("\(scriptBaseName).swift")
        try "#!\(shebang)\n\n\(script)".write(to: file)
        try file.chmod(0o0500)
        return file
      }

      func exec(file: Path) throws -> String? {
        let task = Process(arg0: file)
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "./\(file.basename())"]
        task.currentDirectoryPath = file.parent.string
        let stdout = try task.runSync(.stdout).string?.chuzzled()
        return stdout
      }

      // Note: both files must be created before either is executed to demonstrate the bug
      let file1 = try create(script: "print(123)", inSubDir: "test")
      let file2 = try create(script: "print(456)", inSubDir: "test2")

      let stdout1 = try exec(file: file1)
      expectEqual(stdout1, "123")
      // A stale cache would reuse file1 and print "123" here.
      let stdout2 = try exec(file: file2)
      expectEqual(stdout2, "456")
    }
  }
}

@Suite(.serialized)
struct CacheCleanCommandIntegrationTests {
  @Test func testCanCleanSpecificScripts() throws {
    // In the same temporary directory we create two directories each
    // containing a script of the same name. After executing the new scripts
    // they will both be built in different directories inside of the build
    // directory. Running clean on the first script will remove its build
    // directory but leave the second.
    try Path.mktemp { tmpdir -> Void in

      func create(script: String, inSubDir: String) throws -> Path {
        let scriptDir: Path = try tmpdir.join(inSubDir).mkdir()
        let file = scriptDir.join("\(scriptBaseName).swift")
        try "#!\(shebang)\n\n\(script)".write(to: file)
        try file.chmod(0o0500)
        return file
      }

      func exec(file: Path) throws -> String? {
        let task = Process(arg0: file)
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "./\(file.basename())"]
        task.currentDirectoryPath = file.parent.string
        let stdout = try task.runSync(.stdout).string?.chuzzled()
        return stdout
      }

      func clean(file: Path) throws -> (Process.TerminationReason, Int32) {
        let task = Process()
        task.launchPath = shebang
        task.arguments = ["cache", "clean", file.string]
        try task.go()
        task.waitUntilExit()
        return (task.terminationReason, task.terminationStatus)
      }

      let file1 = try create(script: "print(123)", inSubDir: "\(#function)-1")
      let file2 = try create(script: "print(456)", inSubDir: "\(#function)-2")

      let file1BuildPath = Path.build / file1.resolvedHash
      let file2BuildPath = Path.build / file2.resolvedHash

      let _ = try exec(file: file1)
      let _ = try exec(file: file2)

      expect(file1BuildPath.exists)
      expect(file2BuildPath.exists)

      let (reason, status) = try clean(file: file1)
      expectEqual(reason, .exit)
      expectEqual(status, 0)

      expectFalse(file1BuildPath.exists)
      expect(file2BuildPath.exists)
    }
  }
}

@Suite(.serialized)
struct PackageCommandIntegrationTests {
  @Test func testPackageCopiesByDefault() throws {
    try writePackageScript(script: .resultScript) { file in
      try self.assertPackage(file: file, move: false, force: false)
    }
  }

  @Test func testPackageCanMoveScript() throws {
    try writePackageScript(script: .resultScript) { file in
      try self.assertPackage(file: file, move: true, force: false)
    }
  }

  @Test func testForce() throws {
    try Path.mktemp { tmpdir in
      let file = tmpdir / "foo.swift"
      try String.resultScript.write(to: file)
      try assertPackage(file: file, move: false, force: true)
    }
  }

  @Test func testFilenameDirectoryClash() throws {
    // if the file is `foo` and we will create a package `Foo` in the same directory
    // this is a filename clash on macOS with its case insensitive filesystem
    // and we still should *work*
    //TODO should check the filesystem is insenstive to verify test is working

    try Path.mktemp { tmpdir -> Void in
      let file = tmpdir / "foo"
      try """
      #!/usr/bin/swift sh

      print(123)
      """.write(to: file)

      let task = Process()
      task.launchPath = shebang
      task.arguments = ["package", "--move", file.string]
      try task.go()
      task.waitUntilExit()

      expectEqual(task.terminationReason, .exit)
      expectEqual(task.terminationStatus, 0)

      let d = tmpdir / "Foo"

      expectFalse(file.isFile)
      expect(d.isDirectory)
      expect(d.join("Package.swift").isFile)
      expect(d.join("Sources").isDirectory)
      expect(d.join("Sources/Foo/Foo.swift").isFile)
    }
  }

  @Test func testRelativePath() throws {
    try Path.mktemp { tmpdir -> Void in
      let file = tmpdir / "foo.swift"
      try "#!/usr/bin/swift sh".write(to: file)

      let task = Process()
      task.launchPath = shebang
      task.arguments = ["package", file.basename()]
      task.currentDirectoryPath = tmpdir.string
      try task.go()
      task.waitUntilExit()

      expectEqual(task.terminationReason, .exit)
      expectEqual(task.terminationStatus, 0)

      let d = tmpdir / "Foo"

      expect(file.isFile)
      expect(d.isDirectory)
      expect(d.join("Package.swift").isFile)
      expect(d.join("Sources").isDirectory)
      expect(d.join("Sources/Foo/Foo.swift").isFile)
    }
  }

  @Test func testWorksIfSymlinkBecomesBroken() {
    // creates two scripts for the same cache location
    // thus when the first is complete the `main.swift` symlink becomes broken
    // this is a regression test

    expectRuns(exec: "print(1)", line: 100)
    expectRuns(exec: "print(2)", line: 100)
  }

  @Test func testFailsIfNotScript() throws {
    try Path.mktemp { tmpdir -> Void in
      let file = tmpdir / "foo"
      try "foo".write(to: file)
      let pipe = Pipe()
      let task = Process()
      task.launchPath = shebang
      task.arguments = ["package", file.string]
      task.standardError = pipe
      try task.go()
      task.waitUntilExit()

      let stderr = String(
        data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.chuzzled()

      expectEqual(task.terminationReason, .exit)
      expectEqual(task.terminationStatus, 2)
      expectEqual(stderr, "error: " + PackageError.notScript.errorDescription!)
    }
  }

  @Test func testPackageMapsImportSpecificationConstraints() throws {
    try Path.mktemp { tmpdir in
      let localDependency = try (tmpdir / "local_dep").mkdir()
      let initTask = Process(arg0: Path.swift)
      initTask.arguments = ["package", "init", "--type", "library", "--name", "local_dep"]
      initTask.currentDirectoryPath = localDependency.string
      try initTask.go()
      initTask.waitUntilExit()
      expectEqual(initTask.terminationReason, .exit)
      expectEqual(initTask.terminationStatus, 0)

      let file = tmpdir / "foo.swift"
      try """
      #!/usr/bin/swift sh
      import Path  // mxcl/Path.swift ~> 1.6.0
      import Version  // mxcl/Version == 2.2.1
      import Result  // antitypical/Result == 67613b45
      import StreamReader  // mxcl/StreamReader
      import local_dep  // ./local_dep
      """.write(to: file)

      let task = Process(arg0: shebang)
      task.arguments = ["package", file.string]
      try task.go()
      task.waitUntilExit()
      expectEqual(task.terminationReason, .exit)
      expectEqual(task.terminationStatus, 0)

      let manifest = try String(contentsOf: (tmpdir / "Foo" / "Package.swift").url)
      expect(
        manifest.contains(
          #".package(url: "https://github.com/mxcl/Path.swift.git", from: "1.6.0")"#))
      expect(
        manifest.contains(#".package(url: "https://github.com/mxcl/Version.git", exact: "2.2.1")"#))
      expect(
        manifest.contains(
          #".package(url: "https://github.com/antitypical/Result.git", revision: "67613b45")"#))
      expect(
        manifest.contains(
          #".package(url: "https://github.com/mxcl/StreamReader.git", "0.0.0" ..< "1000000.0.0")"#))
      expect(manifest.contains(#".package(path: "\#(localDependency.string)")"#))
    }
  }

  private func assertPackage(file: Path, move: Bool, force: Bool, line: UInt = #line) throws {
    var arguments = ["package", file.string]
    if force {
      arguments.append("--force")
    }
    if move {
      arguments.append("--move")
    }

    let task = Process(arg0: shebang)
    task.arguments = arguments
    try task.go()
    task.waitUntilExit()

    expectEqual(task.terminationReason, .exit, line: line)
    expectEqual(task.terminationStatus, 0, line: line)

    let name = file.basename(dropExtension: true).capitalized
    let packageDirectory = file.parent / name
    let sources = (packageDirectory / "Sources" / name).ls().filter { $0.extension == "swift" }

    expectEqual(file.exists, !move, line: line)
    expect(packageDirectory.isDirectory, line: line)
    expect(packageDirectory.join("Package.swift").isFile, line: line)
    expectEqual(sources.count, 1, line: line)

    let build = Process(arg0: Path.swift, arg1: "run")
    build.currentDirectoryPath = packageDirectory.string
    let out = try build.runSync(.stdout).string
    expectEqual(out, String.resultScriptOutput, line: line)
  }
}

@Suite(.serialized)
struct SwiftVersionSupportTests {
  @Test func testSwiftVersionIsWhatTestsExpect() {
    let expected = swiftVersion
    expectOutput(
      expected,
      exec: """
        import Foundation

        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["swift", "--version"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try! task.run()
        task.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
        let range = output.range(of: " version \\\\d+\\\\.\\\\d+", options: .regularExpression)!
        print(output[range].split(separator: " ").last!)
        """)
  }
}

private func write(
  script: String, path: Path? = nil, line: UInt = #line, body: @escaping (Path) throws -> Void
) throws {
  let writeFile: (Path) throws -> Void = {
    let file = $0.join("\(scriptBaseName)-\(line).swift")
    try "#!\(shebang)\n\(script)".write(to: file)
    try file.chmod(0o0500)
    try body(file)

  }
  if let path = path {
    try writeFile(path)
  } else {
    try Path.mktemp { tmpDir -> Void in
      try writeFile(tmpDir)
    }
  }
}

private func writePackageScript(
  script: String, line: UInt = #line, body: @escaping (Path) throws -> Void
) throws {
  try Path.mktemp { tmpDir -> Void in
    let file = tmpDir / "foo.swift"
    try "#!/usr/bin/swift sh\n\(script)".write(to: file)
    try file.chmod(0o0500)
    try body(file)
  }
}

private func expectRuns(exec: String, path: Path? = nil, line: UInt = #line) {
  do {
    try write(script: exec, path: path, line: line) { file in
      let task = Process(arg0: file)
      try task.go()
      task.waitUntilExit()

      expectEqual(task.terminationReason, .exit, line: line)
      expectEqual(task.terminationStatus, 0, line: line)
    }
  } catch {
    fail("\(error)", line: line)
  }
}

extension Process {
  fileprivate convenience init(arg0: Path, arg1: String? = nil) {
    self.init(arg0: arg0.string, arg1: arg1)
  }

  fileprivate convenience init(arg0: String, arg1: String? = nil) {
    self.init()
    launchPath = arg0
    arguments = arg1.map { [$0] } ?? []

    func swiftPath() throws -> String {
      let yaml = Path.root.join(#filePath).parent.parent.parent.join(".build/debug.yaml")
      for line in try StreamReader(path: yaml) {
        guard let line = line.chuzzled() else { continue }
        if line.hasPrefix("executable:"), line.hasSuffix("swiftc\"") {
          let parts = line.split(separator: ":")
          guard parts.count == 2 else { continue }
          return Path.root.join(
            parts[1].trimmingCharacters(in: .init(charactersIn: " \n\""))
          ).parent.string
        }
      }
      return "/usr/bin"
    }
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "\(try! swiftPath()):\(ProcessInfo.processInfo.environment["PATH"]!)"
    environment = env
  }
}

private func expectOutput(_ expected: String, exec: String, arg: String? = nil, line: UInt = #line)
{
  do {
    try write(script: exec, line: line) { file in
      let task = Process(arg0: file, arg1: arg)
      let stdout = try task.runSync(.stdout).string?.chuzzled()
      expectEqual(stdout, expected, line: line)
    }
  } catch {
    fail("\(error)", line: line)
  }
}

private var shebang: String {
  return Path.root.join(#filePath).parent.parent.parent.join(".build/debug/swift-sh").string
}

extension String {
  fileprivate static var resultScript: String {
    return """
      import Foundation
      import Result  // @antitypical ~> 4.1

      print(Result<Int, CocoaError>.success(3))
      """
  }

  fileprivate static var resultScriptOutput: String {
    return ".success(3)"
  }
}

private let scriptBaseName = "dev.workspace.swift-sh-tests"
