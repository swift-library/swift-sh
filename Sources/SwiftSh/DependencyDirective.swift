// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SemVer
import SystemPackage

/// A package dependency declared by the trailing comment of an import.
struct DependencyDirective: Equatable, Sendable {
  let module: String
  let source: Source

  enum Source: Equatable, Sendable {
    case remote(url: String, requirement: Requirement)
    case local(FilePath)

    var location: String {
      switch self {
      case .remote(let url, _): return url
      case .local(let path): return path.string
      }
    }

    /// The package identity SwiftPM derives from the last location component.
    var identity: String {
      let basename = location.split(separator: "/").last.map(String.init) ?? location
      return (basename.hasSuffix(".git") ? String(basename.dropLast(4)) : basename).lowercased()
    }
  }

  enum Requirement: Equatable, Sendable {
    case upToNextMajor(Version)
    case exact(Version)
    case revision(String)
    /// Builds against the newest release, selected when the script is first built.
    case unspecified
  }

  /// `releases` maps the URLs of versionless imports to their selected releases.
  func manifestDependency(releases: [String: Version]) throws -> PackageManifest.Dependency {
    switch source {
    case .local(let path): return .local(path: path.string)
    case .remote(let url, .upToNextMajor(let version)):
      return .remote(url: url, requirement: .upToNextMajor(from: version))
    case .remote(let url, .exact(let version)):
      return .remote(url: url, requirement: .exact(version))
    case .remote(let url, .revision(let reference)):
      return .remote(url: url, requirement: .revision(reference))
    case .remote(let url, .unspecified):
      guard let release = releases[url] else { throw ReleaseSelectionError.unselected(url) }
      return .remote(url: url, requirement: .upToNextMajor(from: release))
    }
  }

  var manifestProduct: PackageManifest.Product {
    PackageManifest.Product(name: module, package: source.identity)
  }

  /// Returns nil when the comment is prose rather than a dependency.
  init?(module: String, comment: String, baseDirectory: FilePath) throws {
    let text = comment.trimmingCharacters(in: .whitespaces)
    let isLocal =
      text.hasPrefix("/") || text.hasPrefix("./") || text.hasPrefix("../") || text.hasPrefix("~/")
    guard isLocal || text.hasPrefix("@") || text.hasPrefix("git@") || text.contains("/") else {
      return nil
    }
    self.module = module
    if isLocal {
      let path = absolutePath(text, relativeTo: baseDirectory)
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: path.string, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        throw SourceError.invalidDependency(text)
      }
      source = .local(path)
      return
    }
    let markers = ["~>", "=="].compactMap { marker in text.range(of: marker).map { (marker, $0) } }
    let repository: String
    let requirement: Requirement
    if let (operation, range) = markers.min(by: { $0.1.lowerBound < $1.1.lowerBound }) {
      repository = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
      let operand = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
      guard !operand.isEmpty, !operand.contains(where: \.isWhitespace) else {
        throw SourceError.invalidConstraint(text)
      }
      if let version = Version(lenient: operand) {
        requirement = operation == "~>" ? .upToNextMajor(version) : .exact(version)
      } else {
        requirement = .revision(operand)
      }
    } else {
      repository = text
      requirement = .unspecified
    }
    source = .remote(url: try Self.url(for: repository, module: module), requirement: requirement)
  }

  /// Expands `owner/repo` and `@owner` shorthands to GitHub URLs; Git URLs pass through.
  private static func url(for repository: String, module: String) throws -> String {
    guard !repository.contains(where: \.isWhitespace) else {
      throw SourceError.invalidDependency(repository)
    }
    if repository.hasPrefix("git@"), repository.contains(":") {
      return repository
    }
    if let url = URL(string: repository), let scheme = url.scheme {
      if ["https", "http", "ssh"].contains(scheme), url.host != nil { return repository }
      if scheme == "file", url.path.hasPrefix("/") { return repository }
    }
    let parts =
      repository.hasPrefix("@")
      ? [String(repository.dropFirst()), module]
      : repository.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 2,
      parts.allSatisfy({
        !$0.isEmpty
          && $0.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) })
      })
    else {
      throw SourceError.invalidDependency(repository)
    }
    let owner = parts[0].replacingOccurrences(of: ".", with: "-")
    let name = parts[1].hasSuffix(".git") ? String(parts[1].dropLast(4)) : parts[1]
    return "https://github.com/\(owner)/\(name).git"
  }
}

extension Version {
  /// Script syntax permits a v prefix and omitted minor or patch components.
  init?(lenient operand: String) {
    let value = operand.hasPrefix("v") ? String(operand.dropFirst()) : operand
    let coreEnd = value.firstIndex(where: { $0 == "-" || $0 == "+" }) ?? value.endIndex
    let core = value[..<coreEnd].split(separator: ".", omittingEmptySubsequences: false)
    guard (1...3).contains(core.count) else { return nil }
    let normalized = core.map(String.init) + Array(repeating: "0", count: 3 - core.count)
    self.init(normalized.joined(separator: ".") + value[coreEnd...])
  }
}
