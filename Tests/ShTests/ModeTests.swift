// SPDX-License-Identifier: Unlicense

import Foundation
import SystemPackage
import Testing

@testable import Sh

struct ModeTests {
  @Test(arguments: [
    (["package", "foo"], false, false),
    (["package", "--force", "foo"], true, false),
    (["package", "foo", "--move"], false, true),
    (["package", "--force", "--move", "foo"], true, true),
  ])
  func packaging(_ arguments: [String], force: Bool, move: Bool) throws {
    guard
      case .package(let path, let wantsForce, let wantsMove) = try Mode(
        for: ["swift-sh"] + arguments, isTTY: true)
    else {
      Issue.record("Expected package mode")
      return
    }
    #expect(path == absolutePath("foo"))
    #expect(wantsForce == force)
    #expect(wantsMove == move)
  }

  @Test(arguments: [
    ["package"], ["package", "foo", "bar"], ["cache"], ["cache", "unknown"],
    ["cache", "clean", "foo", "bar"], ["--version", "extra"],
  ])
  func usageErrors(_ arguments: [String]) {
    #expect(throws: CommandLine.Error.self) { try Mode(for: ["swift-sh"] + arguments, isTTY: true) }
  }

  @Test(arguments: [true, false])
  func globalVersionBeforeInputRouting(isTTY: Bool) throws {
    guard case .version = try Mode(for: ["swift-sh", "--version"], isTTY: isTTY) else {
      Issue.record("Expected version mode")
      return
    }
  }

  @Test(arguments: ["-", "--"])
  func explicitStdinForwardsFlags(_ marker: String) throws {
    guard
      case .run(.stdin, let arguments) = try Mode(
        for: ["swift-sh", marker, "--version", "package"], isTTY: true)
    else {
      Issue.record("Expected stdin")
      return
    }
    #expect(Array(arguments) == ["--version", "package"])
  }

  @Test func scriptArgumentsAndImplicitStdin() throws {
    guard
      case .run(.file(let path), let arguments) = try Mode(
        for: ["swift-sh", "script.swift", "--help", "--version"], isTTY: true)
    else {
      Issue.record("Expected a script path")
      return
    }
    #expect(path == absolutePath("script.swift"))
    #expect(Array(arguments) == ["--help", "--version"])
    guard
      case .run(.stdin, let streamed) = try Mode(
        for: ["swift-sh", "hello", "--option"], isTTY: false)
    else {
      Issue.record("Expected implicit stdin")
      return
    }
    #expect(Array(streamed) == ["hello", "--option"])
    #expect(throws: CommandLine.Error.self) { try Mode(for: ["swift-sh"], isTTY: true) }
    guard case .run(.stdin, _) = try Mode(for: ["swift-sh"], isTTY: false) else {
      Issue.record("Expected stdin for a pipe")
      return
    }
  }

  @Test(arguments: [false, true])
  func opening(xcode: Bool) throws {
    let arguments = ["swift-sh", "open", "foo"] + (xcode ? ["--xcode"] : [])
    guard case .open(let path, let wantsXcode) = try Mode(for: arguments, isTTY: true) else {
      Issue.record("Expected open mode")
      return
    }
    #expect(path == absolutePath("foo"))
    #expect(wantsXcode == xcode)
  }

  @Test func cleaningAndHelp() throws {
    guard case .clean(nil) = try Mode(for: ["swift-sh", "cache", "clean"], isTTY: true) else {
      Issue.record("Expected whole-cache clean")
      return
    }
    guard case .clean(let path) = try Mode(for: ["swift-sh", "cache", "clean", "foo"], isTTY: true)
    else {
      Issue.record("Expected one-script clean")
      return
    }
    #expect(path == absolutePath("foo"))
    for arguments in [
      ["--help"], ["-h"], ["help", "package"], ["package", "--help"], ["cache", "clean", "--help"],
    ] {
      guard case .help(let message) = try Mode(for: ["swift-sh"] + arguments, isTTY: true) else {
        Issue.record("Expected help for \(arguments)")
        continue
      }
      #expect(!message.isEmpty)
    }
  }
}
