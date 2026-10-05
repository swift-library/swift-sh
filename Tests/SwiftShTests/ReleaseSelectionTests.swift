// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SemVer
import Subprocess
import SystemPackage
import Testing

@testable import SwiftSh

struct ReleaseSelectionTests {
  @Test func newestStableTagWins() {
    let listing = """
      0123\trefs/tags/v1.2.0
      4567\trefs/tags/1.10.0
      89ab\trefs/tags/2.0.0-beta.1
      cdef\trefs/tags/release-3
      0000\trefs/tags/v1.9.9+build.5
      1111\trefs/heads/9.0.0
      """
    #expect(ReleaseSelection.newestRelease(inTagListing: listing) == Version(1, 10, 0))
    #expect(ReleaseSelection.newestRelease(inTagListing: "2222\trefs/tags/v1.0.0-rc.1") == nil)
  }

  @Test func listsTagsOfAGitRepository() async throws {
    let temporary = try TemporaryDirectory()
    let repository = try await GitRepository(at: temporary.path.appending("fixture"))
    try "1".write(
      to: fileURL(repository.path.appending("VERSION")), atomically: true, encoding: .utf8)
    try await repository.commitAll()
    await #expect(throws: ReleaseSelectionError.noReleases(repository.url)) {
      try await ReleaseSelection.newestRelease(at: repository.url)
    }
    for tag in ["v1.0.0", "1.1.0", "2.0.0-beta.1"] { try await repository.tag(tag) }
    #expect(try await ReleaseSelection.newestRelease(at: repository.url) == Version(1, 1, 0))
    let missing = "file://" + temporary.path.appending("missing").string
    await #expect(throws: ReleaseSelectionError.self) {
      try await ReleaseSelection.newestRelease(at: missing)
    }
  }

  @Test func recordedSelectionsAvoidTheNetwork() async throws {
    let temporary = try TemporaryDirectory()
    let source = ScriptSource(
      path: nil, name: "Script", text: "import Tools // example/swift-sh-missing-fixture\n",
      dependencyDirectory: temporary.path)
    let package = ScriptPackage(
      analysis: try ScriptAnalysis(source: source),
      cache: ScriptCache(root: temporary.path.appending("cache")))
    let url = "https://github.com/example/swift-sh-missing-fixture.git"
    try FileManager.default.createDirectory(
      at: fileURL(package.directory), withIntermediateDirectories: true)
    try JSONEncoder().encode([url: Version(3, 1, 4)]).write(to: fileURL(package.releaseRecord))
    #expect(try await package.selectReleases() == [url: Version(3, 1, 4)])
  }
}

/// A Git repository with fixed identity and no signing, independent of user configuration.
struct GitRepository {
  let path: FilePath
  var url: String { "file://" + path.string }

  init(at path: FilePath) async throws {
    self.path = path
    try FileManager.default.createDirectory(at: fileURL(path), withIntermediateDirectories: true)
    try await git("init", "--quiet")
  }

  func commitAll() async throws {
    try await git("add", "--all")
    try await git("commit", "--quiet", "--message", "fixture")
  }

  func tag(_ name: String) async throws {
    try await git("tag", name)
  }

  private func git(_ arguments: String...) async throws {
    let configuration = [
      "-c", "user.name=swift-sh", "-c", "user.email=swift-sh@example.com",
      "-c", "commit.gpgsign=false", "-c", "tag.gpgsign=false", "-c", "init.defaultBranch=main",
    ]
    let result = try await Subprocess.run(
      .name("git"), arguments: Arguments(configuration + arguments),
      workingDirectory: .init(path.string), output: .discarded, error: .string(limit: 65_536))
    guard result.terminationStatus.isSuccess else {
      throw GitFailure(arguments: arguments, message: result.standardError)
    }
  }
}

struct GitFailure: Error {
  let arguments: [String]
  let message: String
}
