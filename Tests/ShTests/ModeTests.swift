import Path
import Testing

@testable import Sh

@Suite
struct ModeTests {
  @Test func testValidPackage() throws {
    func test(args: String..., line: UInt = #line, force: Bool, move: Bool) throws {
      let mode = try Mode(for: ["arg0"] + args, isTTY: true)
      switch mode {
      case .package(let path, let f, let m):
        expectEqual(f, force, line: line)
        expectEqual(m, move, line: line)
        expectEqual(path, Path.cwd / "foo", line: line)
      default:
        fail("\(mode) for \(args)", line: line)
      }
    }

    try test(args: "package", "foo", force: false, move: false)
    try test(args: "package", "--force", "foo", force: true, move: false)
    try test(args: "package", "foo", "--force", force: true, move: false)
    try test(args: "package", "--move", "foo", force: false, move: true)
    try test(args: "package", "foo", "--move", force: false, move: true)
    try test(args: "package", "--force", "--move", "foo", force: true, move: true)
  }

  @Test func testInvalidPackage() throws {
    expectThrows(try Mode(for: ["arg0", "package"], isTTY: true))
    expectThrows(try Mode(for: ["arg0", "package", "foo", "bar"], isTTY: true))
  }

  @Test func testOpen() throws {
    func test(args: String..., line: UInt = #line, xcode: Bool) throws {
      let mode = try Mode(for: ["arg0"] + args, isTTY: true)
      switch mode {
      case .open(let path, let wantsXcode):
        expectEqual(wantsXcode, xcode, line: line)
        expectEqual(path, Path.cwd / "foo", line: line)
      default:
        fail("\(mode) for \(args)", line: line)
      }
    }

    try test(args: "open", "foo", xcode: false)
    try test(args: "open", "--xcode", "foo", xcode: true)
    try test(args: "open", "foo", "--xcode", xcode: true)
  }

  #if os(macOS)
    @Test func testXcodeOpenInvocation() {
      let invocation = xcodeOpenInvocation(for: Path.root / "tmp" / "SwiftShCache")
      expectEqual(invocation.arg0, "/usr/bin/open")
      expectEqual(invocation.args, ["-a", "Xcode", "/tmp/SwiftShCache"])
    }
  #endif

  @Test func testCacheClean() throws {
    let all = try Mode(for: ["arg0", "cache", "clean"], isTTY: true)
    switch all {
    case .clean(nil):
      break
    default:
      fail("\(all)")
    }

    let one = try Mode(for: ["arg0", "cache", "clean", "foo"], isTTY: true)
    switch one {
    case .clean(.some(let path)):
      expectEqual(path, Path.cwd / "foo")
    default:
      fail("\(one)")
    }
  }

  @Test func testInvalidCache() throws {
    expectThrows(try Mode(for: ["arg0", "cache"], isTTY: true))
    expectThrows(try Mode(for: ["arg0", "cache", "foo"], isTTY: true))
    expectThrows(try Mode(for: ["arg0", "cache", "clean", "foo", "bar"], isTTY: true))
  }

  @Test func testOldCommandsAreNotAliases() throws {
    func testRun(args: String..., line: UInt = #line) throws {
      let mode = try Mode(for: ["arg0"] + args, isTTY: true)
      switch mode {
      case .run(.file(let path), let otherArgs):
        expectEqual(path, Path.cwd / args[0], line: line)
        expectEqual(otherArgs, ArraySlice(args.dropFirst()), line: line)
      default:
        fail("\(mode) for \(args)", line: line)
      }
    }

    try testRun(args: "eject", "foo")
    try testRun(args: "editor", "foo")
    try testRun(args: "edit", "foo")
    try testRun(args: "--clean-cache")
    try testRun(args: "-C", "foo")
  }

  @Test func testValidRun() throws {
    try Path.mktemp { tmpdir in
      let foo = try DynamicPath(tmpdir).foo.touch()

      func test(args: String..., line: UInt = #line) throws {
        let mode = try Mode(for: ["arg0"] + args, isTTY: true)
        switch mode {
        case .run(.file(let path), let otherArgs):
          expectEqual(path, foo, line: line)
          expectEqual(otherArgs, args.dropFirst(), line: line)
        default:
          fail("\(mode) for \(args)", line: line)
        }
      }
      try test(args: foo.string)
      try test(args: foo.string, "--bar")
      try test(args: foo.string, "--help")
      try test(args: foo.string, "--bar", "flubbles")
    }
  }

  @Test func testValidStdinRun() throws {
    func test(args: String..., line: UInt = #line) throws {
      let mode = try Mode(for: ["arg0"] + args, isTTY: false)
      switch mode {
      case .run(.stdin, let otherArgs):
        expectEqual(otherArgs, ArraySlice(args), line: line)
      default:
        fail("\(mode) for \(args)", line: line)
      }
    }
    try test(args: "foo")
    try test(args: "foo", "--bar")
    try test(args: "foo", "--bar", "flubbles")
  }

  @Test func testDash() throws {
    func test(args: String..., line: UInt = #line) throws {
      let mode = try Mode(for: ["arg0"] + args, isTTY: true)
      switch mode {
      case .run(.stdin, let otherArgs):
        expectEqual(otherArgs, args.dropFirst(), line: line)
      default:
        fail("\(mode) for \(args)", line: line)
      }
    }
    try test(args: "-")
    try test(args: "-", "--bar")
    try test(args: "-", "package", "foo")

    try test(args: "--")
    try test(args: "--", "--bar")
    try test(args: "--", "package", "foo")
  }

  @Test func testNoArgs() throws {
    expectThrows(try Mode(for: ["arg0"], isTTY: true))
    expectNoThrow(try Mode(for: ["arg0"], isTTY: false))
  }

  @Test func testHelp() throws {
    func test(args: String..., line: UInt = #line, isTTY: Bool) throws {
      let mode = try Mode(for: ["arg0"] + args, isTTY: isTTY)
      switch mode {
      case .help(let message):
        expect(message.contains("swift sh package"), line: line)
      default:
        fail("\(mode) for \(args)", line: line)
      }
    }

    try test(args: "-h", isTTY: true)
    try test(args: "--help", isTTY: true)

    let packageHelp = try Mode(for: ["arg0", "package", "--help"], isTTY: true)
    switch packageHelp {
    case .help(let message):
      expect(message.contains("package"))
    default:
      fail("\(packageHelp)")
    }

    let helpCommand = try Mode(for: ["arg0", "help", "package"], isTTY: true)
    switch helpCommand {
    case .help(let message):
      expect(message.contains("package"))
    default:
      fail("\(helpCommand)")
    }
  }
}
