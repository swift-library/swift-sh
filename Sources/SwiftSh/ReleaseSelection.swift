// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SemVer
import Subprocess

/// Finds the release that a versionless import builds against: the newest tag that is a
/// semantic version, with or without a `v` prefix, excluding prereleases.
enum ReleaseSelection {
  static func newestRelease(at url: String) async throws -> Version {
    let result = try await Subprocess.run(
      .name("git"), arguments: ["ls-remote", "--tags", "--refs", url],
      environment: .inherit.updating(["GIT_TERMINAL_PROMPT": "0"]),
      output: .string(limit: 16_777_216), error: .string(limit: 65_536))
    guard result.terminationStatus.isSuccess else {
      throw ReleaseSelectionError.listingFailed(
        url, result.standardError.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    guard let version = newestRelease(inTagListing: result.standardOutput) else {
      throw ReleaseSelectionError.noReleases(url)
    }
    return version
  }

  /// Reads `git ls-remote --tags --refs` output.
  static func newestRelease(inTagListing listing: String) -> Version? {
    listing.split(separator: "\n").compactMap { line -> Version? in
      guard let reference = line.split(separator: "\t").last,
        reference.hasPrefix("refs/tags/")
      else { return nil }
      var name = reference.dropFirst("refs/tags/".count)
      if name.hasPrefix("v") { name = name.dropFirst() }
      guard let version = Version(String(name)), !version.isPrerelease else { return nil }
      return version
    }.max()
  }
}

enum ReleaseSelectionError: LocalizedError, Equatable {
  case listingFailed(String, String)
  case noReleases(String)
  case unselected(String)

  var errorDescription: String? {
    switch self {
    case .listingFailed(let url, let message):
      return "Cannot list the release tags of \(url): \(message)"
    case .noReleases(let url):
      return """
        \(url) has no release tags. Add a requirement to the import comment, such as \
        '== main' or '~> 1.0'.
        """
    case .unselected(let url):
      return "No release was selected for \(url)."
    }
  }
}
