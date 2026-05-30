import Path

import class Foundation.ProcessInfo

extension Path {
  public static func which(_ cmd: String) -> Path? {
    for prefix in executableSearchPaths {
      let path = prefix / cmd
      if path.isExecutable {
        return path
      }
    }
    return nil
  }
}

private var executableSearchPaths: [Path] {
  guard let path = ProcessInfo.processInfo.environment["PATH"] else {
    return []
  }
  return path.split(separator: ":").map {
    if $0.first == "/" {
      return Path.root / $0
    } else {
      return Path.cwd / $0
    }
  }
}
