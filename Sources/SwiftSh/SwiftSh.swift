// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import ArgumentParser
import Foundation

@main
struct SwiftSh: AsyncParsableCommand {
  static let version = "0.2.0"

  static let configuration = CommandConfiguration(
    commandName: "swift sh",
    abstract: "Run Swift scripts with SwiftPM dependencies.",
    usage: """
      swift sh [--debug] <script> [arguments...]
      swift sh [--debug] - [arguments...]
      swift sh [--debug] -- [arguments...]
      swift sh package <script> [--force] [--move]
      swift sh open <script> [--xcode]
      swift sh cache clean [<script>]
      """,
    version: version,
    subcommands: [
      RunCommand.self,
      PackageCommand.self,
      OpenCommand.self,
      CacheCommand.self,
    ],
    defaultSubcommand: RunCommand.self)

  /// Usage errors exit with 3 and runtime failures with 2, so a script's own status stays distinct.
  static func main() async {
    do {
      var command = try parseAsRoot()
      if var command = command as? any AsyncParsableCommand {
        try await command.run()
      } else {
        try command.run()
      }
    } catch {
      let status = exitCode(for: error)
      if status == .success {
        print(fullMessage(for: error))
        Foundation.exit(0)
      }
      let message =
        status == .validationFailure
        ? "error: invalid usage\n\(fullMessage(for: error))\n"
        : "error: \(error.localizedDescription)\n"
      FileHandle.standardError.write(Data(message.utf8))
      Foundation.exit(status == .validationFailure ? 3 : 2)
    }
  }
}
