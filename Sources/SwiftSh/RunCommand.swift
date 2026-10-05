// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import ArgumentParser
import Foundation
import SystemPackage

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

struct RunCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "run",
    abstract: "Run a script; this is the default command.",
    discussion: """
      `swift sh run <script>` runs a script whose name matches a subcommand, such as a \
      script named `package`.
      """,
    shouldDisplay: false)

  @Flag(help: "Build the script in debug configuration instead of release.")
  var debug = false

  @Argument(
    parsing: .captureForPassthrough,
    help: "A script path, or - or -- for standard input, followed by the script's arguments.")
  var input: [String] = []

  func validate() throws {
    guard let first = input.first, first.hasPrefix("-"), first != "-", first != "--" else {
      return
    }
    if first == "--help" || first == "-h" {
      throw CleanExit.helpRequest(SwiftSh.self)
    }
    throw ValidationError("Unknown option '\(first)'.")
  }

  /// Standard input is the script only when requested or when it is not a terminal.
  func resolve(isTTY: Bool) throws -> (script: ScriptInput, arguments: [String]) {
    guard let first = input.first else {
      guard !isTTY else {
        throw ValidationError("Provide a script path, or pipe a script to standard input.")
      }
      return (.standardInput, [])
    }
    let arguments = Array(input.dropFirst())
    if first == "-" || first == "--" {
      return (.standardInput, arguments)
    }
    return (.file(absolutePath(first)), arguments)
  }

  func run() async throws {
    let (input, arguments) = try resolve(isTTY: isatty(STDIN_FILENO) == 1)
    let analysis = try ScriptAnalysis(source: ScriptSource(reading: input))
    let cache = ScriptCache()
    let lock = try CacheLock(root: cache.root, key: cache.key(for: analysis.source))
    defer { lock.release() }
    let toolchain = try await SwiftToolchain.discover(cache: cache)
    let package = ScriptPackage(
      analysis: analysis, cache: cache, configuration: debug ? .debug : .release)
    try await package.build(using: toolchain)
    try replaceProcess(with: package.binary.string, arguments: arguments)
  }
}
