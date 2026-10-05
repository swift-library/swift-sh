// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import ArgumentParser
import Foundation
import Subprocess
import SystemPackage

struct OpenCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "open",
    abstract: "Open the generated package for editing.")

  @Flag(help: "Open the generated SwiftPM package in Xcode. Only available on macOS.")
  var xcode = false

  @Argument(help: "The script to open.")
  var script: String

  func run() async throws {
    let analysis = try ScriptAnalysis(source: ScriptSource(reading: .file(absolutePath(script))))
    let cache = ScriptCache()
    let lock = try CacheLock(root: cache.root, key: cache.key(for: analysis.source))
    defer { lock.release() }
    let package = ScriptPackage(analysis: analysis, cache: cache)
    try package.write()
    let launch = try await EditorLaunch(
      for: package, xcode: xcode, environment: ProcessInfo.processInfo.environment)
    if let directory = launch.workingDirectory {
      guard FileManager.default.changeCurrentDirectoryPath(directory.string) else {
        throw CocoaError(.fileReadUnknown)
      }
    }
    try replaceProcess(with: launch.executable, arguments: launch.arguments)
  }
}

/// The process that replaces swift-sh to edit a generated package.
struct EditorLaunch: Equatable {
  let executable: String
  let arguments: [String]
  let workingDirectory: FilePath?

  init(executable: String, arguments: [String], workingDirectory: FilePath? = nil) {
    self.executable = executable
    self.arguments = arguments
    self.workingDirectory = workingDirectory
  }

  init(for package: ScriptPackage, xcode: Bool, environment: [String: String]) async throws {
    if xcode {
      #if os(macOS)
        self.init(
          executable: "/usr/bin/open", arguments: ["-a", "Xcode", package.directory.string])
        return
      #else
        throw OpenError.xcodeUnavailable
      #endif
    }
    guard let editor = environment["EDITOR"], !editor.isEmpty else {
      throw OpenError.editorUndefined
    }
    let executable: Executable =
      editor.contains("/") ? .path(.init(absolutePath(editor).string)) : .name(editor)
    let resolved: FilePath
    do {
      resolved = FilePath(try await executable.resolveExecutablePath(in: .inherit).string)
    } catch {
      throw OpenError.editorNotFound(editor)
    }
    self.init(
      executable: resolved.string, arguments: [package.entry.string],
      workingDirectory: package.directory)
  }
}

enum OpenError: LocalizedError {
  case editorUndefined
  case editorNotFound(String)
  case xcodeUnavailable

  var errorDescription: String? {
    switch self {
    case .editorNotFound(let editor): return "EDITOR not in PATH: \(editor)"
    case .editorUndefined: return "EDITOR undefined"
    case .xcodeUnavailable: return "Xcode editing is only available on macOS"
    }
  }
}
