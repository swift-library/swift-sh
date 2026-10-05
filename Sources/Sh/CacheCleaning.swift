// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SystemPackage

func clean(_ script: FilePath?) throws {
  if let script, !FileManager.default.fileExists(atPath: script.string) {
    throw CocoaError(.fileNoSuchFile)
  }
  try BuildCache().clean(script)
}
