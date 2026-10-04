// SPDX-License-Identifier: Unlicense

import ArgumentParser
import Foundation
import SystemPackage

extension CommandLine {
  static var usage: String {
    SwiftShCommand.helpMessage()
  }

  enum Error: LocalizedError {
    case invalidUsage(String)

    var errorDescription: String? {
      switch self {
      case .invalidUsage(let message):
        return message
      }
    }
  }
}

private struct SwiftShCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "swift sh",
    abstract: "Run Swift scripts with SwiftPM dependencies.",
    usage: """
      swift sh <script> [arguments...]
      swift sh - [arguments...]
      swift sh -- [arguments...]
      swift sh package <script> [--force] [--move]
      swift sh open <script> [--xcode]
      swift sh cache clean [<script>]
      """,
    version: releaseVersion,
    subcommands: [
      PackageCommand.self,
      OpenCommand.self,
      CacheCommand.self,
    ])
}

private struct PackageCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "package",
    abstract: "Create a SwiftPM package from a swift-sh script.")

  @Argument(help: "The script to package.")
  var script: String

  @Flag(help: "Package the file even if it does not have a swift-sh shebang.")
  var force = false

  @Flag(help: "Move the script into the generated package instead of copying it.")
  var move = false
}

private struct OpenCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "open",
    abstract: "Open the generated package for editing.")

  @Flag(help: "Open the generated SwiftPM package in Xcode. Only available on macOS.")
  var xcode = false

  @Argument(help: "The script to open.")
  var script: String
}

private struct CacheCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "cache",
    abstract: "Manage the swift-sh cache.",
    subcommands: [CacheCleanCommand.self])
}

private struct CacheCleanCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "clean",
    abstract: "Delete cached script builds.")

  @Argument(help: "A script whose cache should be deleted.")
  var script: String?
}

//MARK: Mode

enum Mode {
  case run(RunType, args: ArraySlice<String>)
  case package(FilePath, force: Bool, move: Bool)
  case open(FilePath, xcode: Bool)
  case clean(FilePath?)
  case help(String)
  case version

  enum RunType {
    case stdin
    case file(FilePath)
  }

  init(for args: [String], isTTY: Bool) throws {
    let arguments = Array(args.dropFirst())
    guard let command = arguments.first else {
      if isTTY {
        throw CommandLine.Error.invalidUsage(CommandLine.usage)
      } else {
        self = .run(.stdin, args: [])
        return
      }
    }

    switch command {
    case "package":
      let rest = Array(arguments.dropFirst())
      if Self.isHelpRequest(rest) {
        self = .help(PackageCommand.helpMessage())
      } else {
        let command = try Self.parse(PackageCommand.self, arguments: rest)
        self = .package(command.script.asFilePath, force: command.force, move: command.move)
      }
    case "open":
      let rest = Array(arguments.dropFirst())
      if Self.isHelpRequest(rest) {
        self = .help(OpenCommand.helpMessage())
      } else {
        let command = try Self.parse(OpenCommand.self, arguments: rest)
        self = .open(command.script.asFilePath, xcode: command.xcode)
      }
    case "cache":
      self = try Self.parseCache(Array(arguments.dropFirst()))
    case "help":
      self = try Self.parseHelp(Array(arguments.dropFirst()))
    case "-", "--":
      self = .run(.stdin, args: ArraySlice(arguments.dropFirst()))
    case "--version":
      guard arguments.count == 1 else {
        throw CommandLine.Error.invalidUsage("--version accepts no arguments.")
      }
      self = .version
    case "--help", "-h":
      self = .help(CommandLine.usage)
    default:
      self = .run(.file(command.asFilePath), args: ArraySlice(arguments.dropFirst()))
    }
  }

  private static func parse<T: ParsableArguments>(_ type: T.Type, arguments: [String]) throws -> T {
    do {
      return try type.parse(arguments)
    } catch {
      throw CommandLine.Error.invalidUsage(type.fullMessage(for: error))
    }
  }

  private static func parseCache(_ arguments: [String]) throws -> Mode {
    if isHelpRequest(arguments) {
      return .help(CacheCommand.helpMessage())
    }
    guard let subcommand = arguments.first else {
      throw CommandLine.Error.invalidUsage(CacheCommand.helpMessage())
    }
    if subcommand == "help" {
      if arguments.dropFirst().first == "clean" {
        return .help(CacheCleanCommand.helpMessage())
      }
      return .help(CacheCommand.helpMessage())
    }
    guard subcommand == "clean" else {
      throw CommandLine.Error.invalidUsage(CacheCommand.helpMessage())
    }
    let rest = Array(arguments.dropFirst())
    if isHelpRequest(rest) {
      return .help(CacheCleanCommand.helpMessage())
    }
    let command = try parse(CacheCleanCommand.self, arguments: rest)
    return .clean(command.script.map { $0.asFilePath })
  }

  private static func parseHelp(_ arguments: [String]) throws -> Mode {
    guard let topic = arguments.first else {
      return .help(CommandLine.usage)
    }
    switch topic {
    case "package":
      return .help(PackageCommand.helpMessage())
    case "open":
      return .help(OpenCommand.helpMessage())
    case "cache":
      if arguments.dropFirst().first == "clean" {
        return .help(CacheCleanCommand.helpMessage())
      }
      return .help(CacheCommand.helpMessage())
    default:
      throw CommandLine.Error.invalidUsage(CommandLine.usage)
    }
  }

  private static func isHelpRequest(_ arguments: [String]) -> Bool {
    return arguments.contains("--help") || arguments.contains("-h")
  }
}

extension String {
  fileprivate var asFilePath: FilePath {
    absolutePath(self)
  }
}
