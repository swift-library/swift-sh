import Foundation
import Path
import StreamReader

public func open(path: Path, xcode: Bool) throws -> Never {
  let script = try scriptForOpening(path)
  try script.write()

  if xcode {
    #if os(macOS)
      let invocation = xcodeOpenInvocation(for: script.buildDirectory)
      try exec(arg0: invocation.arg0, args: invocation.args)
    #else
      throw OpenError.xcodeUnavailable
    #endif
  } else {
    guard let editor = ProcessInfo.processInfo.environment["EDITOR"] else {
      throw OpenError.editorUndefined
    }
    guard let editorPath = Path(editor) ?? Path.which(editor) else {
      throw OpenError.editorNotFound(editor)
    }
    chdir(script.buildDirectory.string)
    try exec(arg0: editorPath.string, args: [script.mainSwift.string])
  }
}

enum OpenError: LocalizedError {
  case editorUndefined
  case editorNotFound(String)
  case xcodeUnavailable

  var errorDescription: String? {
    switch self {
    case .editorUndefined:
      return "EDITOR undefined"
    case .editorNotFound(let editor):
      return "EDITOR not in PATH: \(editor)"
    case .xcodeUnavailable:
      return "Xcode editing is only available on macOS"
    }
  }
}

private func scriptForOpening(_ path: Path) throws -> Script {
  let input: Script.Input = .path(path)
  let reader = try StreamReader(path: path)
  var style: ExecutableTargetMainStyle = .topLevelCode
  let deps: [ImportSpecification] = try reader.compactMap { line in
    if line.contains("@main") && !(line.contains("//") || line.contains("/*")) {
      style = .mainAttribute
    }
    return try ImportSpecification(line: line, from: input)
  }
  return Script(for: .path(path), style: style, dependencies: deps)
}

func xcodeOpenInvocation(for packageDirectory: Path) -> (arg0: String, args: [String]) {
  return ("/usr/bin/open", ["-a", "Xcode", packageDirectory.string])
}
