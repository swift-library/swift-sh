// SPDX-License-Identifier: Unlicense

import Foundation
import SystemPackage

#if canImport(CryptoKit)
  import CryptoKit
#else
  import Crypto
#endif
#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

func digest(_ value: String) -> String {
  SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
}

struct BuildCache: Sendable {
  let root: FilePath

  init(root: FilePath? = nil) {
    if let root {
      self.root = root
    } else if let parent = ProcessInfo.processInfo.environment["XDG_CACHE_HOME"] {
      self.root = absolutePath(parent).appending("swift-sh")
    } else {
      #if os(macOS)
        self.root = FilePath(FileManager.default.homeDirectoryForCurrentUser.path).appending(
          "Library/Developer/swift-sh.cache")
      #else
        self.root = FilePath(FileManager.default.homeDirectoryForCurrentUser.path).appending(
          ".cache/swift-sh")
      #endif
    }
  }

  func key(for source: ScriptSource) -> String {
    if let path = source.path { return digest(path.string) }
    return digest(source.name + "\u{0}" + source.dependencyDirectory.string + "\u{0}" + source.text)
  }

  func directory(for source: ScriptSource) -> FilePath {
    root.appending(key(for: source))
  }

  func clean(_ script: FilePath?) throws {
    let key = script.map { digest(fileURL($0).resolvingSymlinksInPath().path) }
    let lock = try CacheLock(root: root, key: key)
    defer { lock.release() }
    let directory = key.map { root.appending($0) } ?? root
    if FileManager.default.fileExists(atPath: directory.string) {
      try FileManager.default.removeItem(at: fileURL(directory))
    }
  }
}

/// Locks live outside the removable cache; descriptors close across final exec.
final class CacheLock {
  private var descriptors: [FileDescriptor] = []

  init(root: FilePath, key: String?) throws {
    let locks = root.removingLastComponent().appending(".swift-sh-locks")
    try FileManager.default.createDirectory(at: fileURL(locks), withIntermediateDirectories: true)
    do {
      try acquire(
        locks.appending(digest(root.string) + ".lock"), operation: key == nil ? LOCK_EX : LOCK_SH)
      if let key {
        try acquire(locks.appending(digest(root.string) + "-" + key + ".lock"), operation: LOCK_EX)
      }
    } catch {
      release()
      throw error
    }
  }

  private func acquire(_ path: FilePath, operation: Int32) throws {
    let descriptor = try FileDescriptor.open(
      path, .readWrite, options: [.create, .closeOnExec], permissions: .ownerReadWrite)
    descriptors.append(descriptor)
    guard flock(descriptor.rawValue, operation) == 0 else { throw Errno(rawValue: errno) }
  }

  func release() {
    for descriptor in descriptors.reversed() { try? descriptor.close() }
    descriptors = []
  }

  deinit { release() }
}
