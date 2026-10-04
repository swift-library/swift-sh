// SPDX-License-Identifier: Unlicense

import Foundation
import SystemPackage

final class TemporaryDirectory: Sendable {
  let path: FilePath

  init(parent: FilePath? = nil) throws {
    let base = parent.map(fileURL) ?? FileManager.default.temporaryDirectory
    path = FilePath(base.appendingPathComponent(".swift-sh-" + UUID().uuidString).path)
    try FileManager.default.createDirectory(at: fileURL(path), withIntermediateDirectories: true)
  }

  deinit { try? FileManager.default.removeItem(at: fileURL(path)) }
}
