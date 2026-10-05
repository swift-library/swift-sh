// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SystemPackage

#if os(Linux)
  import Glibc
#else
  import Darwin
#endif

/// Generated script packages, keyed by script path or by standard input content.
struct ScriptCache: Sendable {
  let root: FilePath
  /// Locations written by earlier releases, removed when the whole cache is cleaned.
  let legacyLocations: [FilePath]

  init(root: FilePath, legacyLocations: [FilePath] = []) {
    self.root = root
    self.legacyLocations = legacyLocations
  }

  /// Uses `XDG_CACHE_HOME` when it holds an absolute path, and otherwise the platform cache
  /// directory: `~/Library/Caches` on macOS and `~/.cache` elsewhere.
  init(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    home: FilePath = FilePath(FileManager.default.homeDirectoryForCurrentUser.path)
  ) {
    if let parent = environment["XDG_CACHE_HOME"], parent.hasPrefix("/") {
      self.init(root: FilePath(parent).appending("swift-sh"))
      return
    }
    #if os(macOS)
      self.init(
        root: home.appending("Library/Caches/swift-sh"),
        legacyLocations: [
          home.appending("Library/Developer/swift-sh.cache"),
          home.appending("Library/Developer/.swift-sh-locks"),
        ])
    #else
      self.init(root: home.appending(".cache/swift-sh"))
    #endif
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
    let directories = key.map { [root.appending($0)] } ?? [root] + legacyLocations
    for directory in directories
    where (try? FileManager.default.attributesOfItem(atPath: directory.string)) != nil {
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
