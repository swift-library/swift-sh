// SPDX-License-Identifier: Unlicense

import Foundation
import Subprocess
import SystemPackage

func open(path: FilePath, xcode: Bool) async throws -> Never {
  let analysis = try ScriptAnalysis(source: ScriptSource(reading: .file(path)))
  let cache = BuildCache()
  let lock = try CacheLock(root: cache.root, key: cache.key(for: analysis.source))
  defer { lock.release() }
  let script = Script(analysis: analysis, cache: cache)
  try script.write()
  if xcode {
    #if os(macOS)
      try exec(arg0: "/usr/bin/open", args: ["-a", "Xcode", script.directory.string])
    #else
      throw OpenError.xcodeUnavailable
    #endif
  }
  guard let editor = ProcessInfo.processInfo.environment["EDITOR"], !editor.isEmpty else {
    throw OpenError.editorUndefined
  }
  let executable: Executable =
    editor.contains("/") ? .path(.init(absolutePath(editor).string)) : .name(editor)
  let editorPath: FilePath
  do {
    let resolved = try await executable.resolveExecutablePath(in: .inherit)
    editorPath = FilePath(resolved.string)
  } catch {
    throw OpenError.editorNotFound(editor)
  }
  guard FileManager.default.changeCurrentDirectoryPath(script.directory.string) else {
    throw CocoaError(.fileReadUnknown)
  }
  try exec(arg0: editorPath.string, args: [script.entry.string])
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
