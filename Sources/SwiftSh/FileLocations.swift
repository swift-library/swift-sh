// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SystemPackage

func fileURL(_ path: FilePath) -> URL {
  URL(fileURLWithPath: path.string)
}

func absolutePath(_ value: String, relativeTo directory: FilePath? = nil) -> FilePath {
  let expanded = (value as NSString).expandingTildeInPath
  let base =
    directory.map(fileURL) ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  return FilePath(URL(fileURLWithPath: expanded, relativeTo: base).standardizedFileURL.path)
}

func swiftLiteral(_ value: String) -> String {
  var result = "\""
  for scalar in value.unicodeScalars {
    switch scalar {
    case "\"": result += "\\\""
    case "\\": result += "\\\\"
    case "\n": result += "\\n"
    case "\r": result += "\\r"
    case "\t": result += "\\t"
    case _ where scalar.value < 32: result += "\\u{\(String(scalar.value, radix: 16))}"
    default: result.unicodeScalars.append(scalar)
    }
  }
  return result + "\""
}
