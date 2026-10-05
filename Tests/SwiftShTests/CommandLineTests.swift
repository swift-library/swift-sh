// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import ArgumentParser
import Foundation
import SystemPackage
import Testing

@testable import SwiftSh

struct CommandLineTests {
  @Test(arguments: [
    (["package", "foo"], false, false),
    (["package", "--force", "foo"], true, false),
    (["package", "foo", "--move"], false, true),
    (["package", "--force", "--move", "foo"], true, true),
  ])
  func packaging(_ arguments: [String], force: Bool, move: Bool) throws {
    let command = try #require(try SwiftSh.parseAsRoot(arguments) as? PackageCommand)
    #expect(command.script == "foo")
    #expect(command.force == force)
    #expect(command.move == move)
  }

  @Test(arguments: [
    ["package"], ["package", "foo", "bar"], ["cache", "unknown"], ["cache", "clean", "foo", "bar"],
    ["--version", "extra"], ["--unknown", "script.swift"],
  ])
  func usageErrors(_ arguments: [String]) {
    #expect(status(for: arguments) == .validationFailure)
  }

  @Test func cacheRequiresSubcommand() throws {
    var command = try SwiftSh.parseAsRoot(["cache"])
    let error = #expect(throws: ValidationError.self) { try command.run() }
    #expect(error.map { SwiftSh.exitCode(for: $0) } == .validationFailure)
  }

  @Test func globalVersionBeforeInputRouting() {
    #expect(status(for: ["--version"]) == .success)
    #expect(message(for: ["--version"]) == SwiftSh.version)
  }

  @Test(arguments: ["-", "--"])
  func explicitStandardInputForwardsFlags(_ marker: String) throws {
    for isTTY in [true, false] {
      let (input, arguments) = try run([marker, "--version", "package"]).resolve(isTTY: isTTY)
      #expect(input == .standardInput)
      #expect(arguments == ["--version", "package"])
    }
  }

  @Test(arguments: [true, false])
  func scriptArgumentsAndImplicitStandardInput(isTTY: Bool) throws {
    let (input, arguments) = try run(["missing.swift", "--help", "--version"])
      .resolve(isTTY: isTTY)
    #expect(input == .file(absolutePath("missing.swift")))
    #expect(arguments == ["--help", "--version"])
    #expect(throws: ValidationError.self) { try run([]).resolve(isTTY: true) }
    let (streamed, streamedArguments) = try run([]).resolve(isTTY: false)
    #expect(streamed == .standardInput)
    #expect(streamedArguments.isEmpty)
  }

  @Test(arguments: [["run", "package"], ["run", "--", "cache"]])
  func explicitRunReachesScriptsNamedLikeSubcommands(_ arguments: [String]) throws {
    let (input, forwarded) = try run(arguments).resolve(isTTY: true)
    if arguments[1] == "--" {
      #expect(input == .standardInput)
      #expect(forwarded == ["cache"])
    } else {
      #expect(input == .file(absolutePath("package")))
      #expect(forwarded.isEmpty)
    }
  }

  @Test(arguments: [false, true])
  func opening(xcode: Bool) throws {
    let arguments = ["open", "foo"] + (xcode ? ["--xcode"] : [])
    let command = try #require(try SwiftSh.parseAsRoot(arguments) as? OpenCommand)
    #expect(command.script == "foo")
    #expect(command.xcode == xcode)
  }

  @Test func cleaningAndHelp() throws {
    let all = try #require(try SwiftSh.parseAsRoot(["cache", "clean"]) as? CacheCleanCommand)
    #expect(all.script == nil)
    let one = try #require(
      try SwiftSh.parseAsRoot(["cache", "clean", "foo"]) as? CacheCleanCommand)
    #expect(one.script == "foo")
    for arguments in [
      ["--help"], ["-h"], ["-h", "extra"], ["help", "package"], ["package", "--help"],
      ["cache", "clean", "--help"],
    ] {
      let help = try #require(helpMessage(for: arguments), "\(arguments)")
      #expect(help.contains("USAGE:"), "\(arguments)")
    }
  }

  private func run(_ arguments: [String]) throws -> RunCommand {
    try #require(try SwiftSh.parseAsRoot(arguments) as? RunCommand)
  }

  private func status(for arguments: [String]) -> ExitCode? {
    do {
      _ = try SwiftSh.parseAsRoot(arguments)
      return nil
    } catch {
      return SwiftSh.exitCode(for: error)
    }
  }

  private func message(for arguments: [String]) -> String {
    do {
      _ = try SwiftSh.parseAsRoot(arguments)
      return ""
    } catch {
      return SwiftSh.fullMessage(for: error)
    }
  }

  /// Help arrives either as a parse error or as ArgumentParser's help command, which throws it.
  private func helpMessage(for arguments: [String]) -> String? {
    do {
      var command = try SwiftSh.parseAsRoot(arguments)
      guard !(command is any AsyncParsableCommand), !(command is CacheCommand),
        !(command is CacheCleanCommand)
      else { return nil }
      try command.run()
      return nil
    } catch {
      return SwiftSh.exitCode(for: error) == .success ? SwiftSh.fullMessage(for: error) : nil
    }
  }
}
