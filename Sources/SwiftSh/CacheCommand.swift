// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import ArgumentParser
import Foundation

struct CacheCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "cache",
    abstract: "Manage the swift-sh cache.",
    subcommands: [CacheCleanCommand.self])

  func run() throws {
    throw ValidationError("Missing subcommand; use 'swift sh cache clean'.")
  }
}

struct CacheCleanCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "clean",
    abstract: "Delete cached script builds.")

  @Argument(help: "A script whose cache should be deleted.")
  var script: String?

  func run() throws {
    let path = script.map { absolutePath($0) }
    if let path, !FileManager.default.fileExists(atPath: path.string) {
      throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: path.string])
    }
    try ScriptCache().clean(path)
  }
}
