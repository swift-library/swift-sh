// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SystemPackage
import Testing

@testable import SwiftSh

struct ScriptCacheTests {
  @Test func absoluteXDGCacheHomeWins() {
    let cache = ScriptCache(
      environment: ["XDG_CACHE_HOME": "/srv/cache"], home: "/tmp/swift-sh-home")
    #expect(cache.root == "/srv/cache/swift-sh")
    #expect(cache.legacyLocations.isEmpty)
  }

  @Test(arguments: ["", "relative/cache"])
  func invalidXDGCacheHomeFallsBackToThePlatformDirectory(_ value: String) {
    let cache = ScriptCache(environment: ["XDG_CACHE_HOME": value], home: "/tmp/swift-sh-home")
    #expect(cache.root == ScriptCache(environment: [:], home: "/tmp/swift-sh-home").root)
  }

  @Test func platformDirectory() {
    let cache = ScriptCache(environment: [:], home: "/tmp/swift-sh-home")
    #if os(macOS)
      #expect(cache.root == "/tmp/swift-sh-home/Library/Caches/swift-sh")
      #expect(
        cache.legacyLocations == [
          "/tmp/swift-sh-home/Library/Developer/swift-sh.cache",
          "/tmp/swift-sh-home/Library/Developer/.swift-sh-locks",
        ])
    #else
      #expect(cache.root == "/tmp/swift-sh-home/.cache/swift-sh")
      #expect(cache.legacyLocations.isEmpty)
    #endif
  }

  @Test func cleaningEverythingRemovesLegacyLocations() throws {
    let temporary = try TemporaryDirectory()
    let legacy = temporary.path.appending("legacy cache")
    let cache = ScriptCache(
      root: temporary.path.appending("cache/swift-sh"), legacyLocations: [legacy])
    for directory in [cache.root.appending("key"), legacy.appending("key")] {
      try FileManager.default.createDirectory(
        at: fileURL(directory), withIntermediateDirectories: true)
    }
    let script = temporary.path.appending("script.swift")
    try "print(1)\n".write(to: fileURL(script), atomically: true, encoding: .utf8)
    try cache.clean(script)
    #expect(FileManager.default.fileExists(atPath: legacy.string))
    try cache.clean(nil)
    #expect(!FileManager.default.fileExists(atPath: cache.root.string))
    #expect(!FileManager.default.fileExists(atPath: legacy.string))
  }
}
