// SPDX-License-Identifier: Unlicense

import Foundation
import SystemPackage

func clean(_ script: FilePath?) throws {
  if let script, !FileManager.default.fileExists(atPath: script.string) {
    throw CocoaError(.fileNoSuchFile)
  }
  try BuildCache().clean(script)
}
