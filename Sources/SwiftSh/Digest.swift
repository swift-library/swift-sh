// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SystemPackage

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif

/// The hexadecimal SHA-256 digest of `value`.
func digest(_ value: String) -> String {
  hexadecimal(SHA256.hash(data: Data(value.utf8)))
}

/// Hashes the paths and contents of the regular files below `directories`. Hidden files and
/// directories, such as `.build` and `.git`, are skipped.
func contentDigest(of directories: [FilePath]) throws -> String {
  var hasher = SHA256()
  for directory in directories {
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: directory.string, isDirectory: &isDirectory),
      isDirectory.boolValue,
      let enumerator = FileManager.default.enumerator(
        at: fileURL(directory), includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles])
    else { throw SourceError.invalidDependency(directory.string) }
    var files: [URL] = []
    for case let url as URL in enumerator
    where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
      files.append(url)
    }
    for file in files.sorted(by: { $0.path < $1.path }) {
      let contents = try Data(contentsOf: file, options: .mappedIfSafe)
      hasher.update(data: Data((file.path + "\u{0}" + String(contents.count) + "\u{0}").utf8))
      hasher.update(data: contents)
    }
  }
  return hexadecimal(hasher.finalize())
}

private func hexadecimal(_ digest: SHA256.Digest) -> String {
  digest.map { String(format: "%02x", $0) }.joined()
}
