// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SystemPackage
import Testing

@testable import SwiftSh

struct DigestTests {
  @Test func contentDigestFollowsContentsNotTimestamps() throws {
    let temporary = try TemporaryDirectory()
    let library = temporary.path.appending("library")
    let file = library.appending("Sources/Library.swift")
    try FileManager.default.createDirectory(
      at: fileURL(file.removingLastComponent()), withIntermediateDirectories: true)
    try "let value = 1\n".write(to: fileURL(file), atomically: true, encoding: .utf8)
    let timestamp = Date(timeIntervalSince1970: 1_000_000_000)
    try FileManager.default.setAttributes([.modificationDate: timestamp], ofItemAtPath: file.string)
    let original = try contentDigest(of: [library])

    try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.string)
    #expect(try contentDigest(of: [library]) == original)

    try "let value = 2\n".write(to: fileURL(file), atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.modificationDate: timestamp], ofItemAtPath: file.string)
    #expect(try contentDigest(of: [library]) != original)
  }

  @Test func hiddenEntriesAreIgnored() throws {
    let temporary = try TemporaryDirectory()
    let library = temporary.path.appending("library")
    try FileManager.default.createDirectory(
      at: fileURL(library.appending(".build")), withIntermediateDirectories: true)
    try "visible".write(
      to: fileURL(library.appending("Package.swift")), atomically: true, encoding: .utf8)
    let original = try contentDigest(of: [library])
    try "artifact".write(
      to: fileURL(library.appending(".build/output")), atomically: true, encoding: .utf8)
    try "state".write(to: fileURL(library.appending(".hidden")), atomically: true, encoding: .utf8)
    #expect(try contentDigest(of: [library]) == original)
    #expect(throws: SourceError.self) {
      try contentDigest(of: [temporary.path.appending("missing")])
    }
  }
}
