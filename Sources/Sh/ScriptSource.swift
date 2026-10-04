// SPDX-License-Identifier: Unlicense

import Foundation
import SystemPackage

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

/// Owns one UTF-8 source snapshot and the directory used to resolve local dependencies.
struct ScriptSource: Sendable {
  let path: FilePath?
  let name: String
  let text: String
  let dependencyDirectory: FilePath

  init(path: FilePath?, name: String, text: String, dependencyDirectory: FilePath) {
    self.path = path
    self.name = name
    self.text = text
    self.dependencyDirectory = dependencyDirectory
  }

  init(reading input: Mode.RunType) throws {
    let data: Data
    switch input {
    case .stdin:
      data = try FileHandle.standardInput.readToEnd() ?? Data()
      path = nil
      name = "StandardInput"
      dependencyDirectory = absolutePath(FileManager.default.currentDirectoryPath)
    case .file(let file):
      let descriptor: FileDescriptor
      do {
        descriptor = try FileDescriptor.open(file, .readOnly, options: [.closeOnExec])
      } catch let error as Errno {
        throw SourceError.unreadableScript(file.string, error.rawValue)
      }
      let handle = FileHandle(fileDescriptor: descriptor.rawValue, closeOnDealloc: true)
      defer { try? handle.close() }
      var attributes = stat()
      guard fstat(descriptor.rawValue, &attributes) == 0 else { throw Errno(rawValue: errno) }
      data = try handle.readToEnd() ?? Data()
      if attributes.st_mode & S_IFMT == S_IFIFO {
        path = nil
        name = "NamedPipe"
        dependencyDirectory = absolutePath(FileManager.default.currentDirectoryPath)
      } else {
        let resolved = FilePath(fileURL(file).resolvingSymlinksInPath().path)
        path = resolved
        name = fileURL(file).deletingPathExtension().lastPathComponent
        dependencyDirectory = resolved.removingLastComponent()
      }
    }
    guard let text = String(data: data, encoding: .utf8) else { throw SourceError.invalidUTF8 }
    self.text = text
  }

  /// Replaces only the leading interpreter directive, preserving subsequent line numbers.
  var compilableText: String {
    guard text.hasPrefix("#!") else { return text }
    let bytes = Array(text.utf8)
    guard let newline = bytes.firstIndex(of: 10) else { return "// swift-sh script" }
    return "// swift-sh script" + String(decoding: bytes[newline...], as: UTF8.self)
  }
}

enum SourceError: LocalizedError {
  case unreadableScript(String, Int32)
  case invalidUTF8
  case invalidDependency(String)
  case invalidConstraint(String)
  case unsupportedSwiftPMPath(String)

  var errorDescription: String? {
    switch self {
    case .unreadableScript(let path, let code):
      return "Cannot open script \(path): \(strerror(code))"
    case .invalidUTF8: return "Script input must be valid UTF-8."
    case .invalidDependency(let value): return "Invalid dependency specification: \(value)"
    case .invalidConstraint(let value): return "Invalid dependency constraint: \(value)"
    case .unsupportedSwiftPMPath(let value):
      return
        "SwiftPM cannot build paths containing double quotes, backslashes, or control characters: \(swiftLiteral(value))"
    }
  }
}
