// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

do {
  let mode = try Mode(for: CommandLine.arguments, isTTY: isatty(STDIN_FILENO) == 1)
  switch mode {
  case .run(let input, let arguments): try await run(input, arguments: Array(arguments))
  case .package(let path, let force, let move): try await package(path, force: force, move: move)
  case .open(let path, let xcode): try await open(path: path, xcode: xcode)
  case .clean(let path): try clean(path)
  case .help(let message): print(message)
  case .version: print(releaseVersion)
  }
} catch let error as CommandLine.Error {
  try FileHandle.standardError.write(
    contentsOf: Data("error: invalid usage\n\(error.errorDescription ?? CommandLine.usage)\n".utf8))
  exit(3)
} catch {
  try FileHandle.standardError.write(
    contentsOf: Data("error: \(error.localizedDescription)\n".utf8))
  exit(2)
}
