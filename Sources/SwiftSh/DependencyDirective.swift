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

    var addDependencyArguments: [String] {
      switch self {
      case .local: return ["--type", "path"]
      case .remote(_, .upToNextMajor(let version)): return ["--from", version.description]
      case .remote(_, .exact(let version)): return ["--exact", version.description]
      case .remote(_, .revision(let reference)): return ["--revision", reference]
      case .remote(_, .unspecified): return ["--from", "0.0.0", "--to", "1000000.0.0"]
      }
    }
  }

  enum Requirement: Equatable, Sendable {
    case upToNextMajor(Version)
    case exact(Version)
    case revision(String)
    case unspecified
  }

  var packageLine: String {
    switch source {
    case .local(let path): return ".package(path: \(swiftLiteral(path.string)))"
    case .remote(let url, let requirement):
      let argument: String
      switch requirement {
      case .upToNextMajor(let version): argument = "from: \(swiftLiteral(version.description))"
      case .exact(let version): argument = "exact: \(swiftLiteral(version.description))"
      case .revision(let reference): argument = "revision: \(swiftLiteral(reference))"
      case .unspecified: argument = "\"0.0.0\"..<\"1000000.0.0\""
      }
      return ".package(url: \(swiftLiteral(url)), \(argument))"
    }
  }

  var productLine: String {
    ".product(name: \(swiftLiteral(module)), package: \(swiftLiteral(source.identity)))"
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

  /// Expands `owner/repo` and `@owner` shorthands to GitHub URLs; full Git URLs pass through.
  private static func url(for repository: String, module: String) throws -> String {
    guard !repository.contains(where: \.isWhitespace) else {
      throw SourceError.invalidDependency(repository)
    }
    if repository.hasPrefix("git@"), repository.contains(":") {
      return repository
    }
    if let url = URL(string: repository), let scheme = url.scheme,
      ["https", "http", "ssh"].contains(scheme), url.host != nil
    {
      return repository
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
