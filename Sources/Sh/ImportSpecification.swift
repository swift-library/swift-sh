// SPDX-License-Identifier: Unlicense

import Foundation
import SemVer
import SystemPackage

struct ImportSpecification: Equatable, Sendable {
  let importName: String
  let dependencyName: DependencyName
  let constraint: Constraint

  enum DependencyName: Equatable, Sendable {
    case remote(String)
    case local(FilePath)

    var location: String {
      switch self {
      case .remote(let url): return url
      case .local(let path): return path.string
      }
    }

    var identity: String {
      let basename = location.split(separator: "/").last.map(String.init) ?? location
      return (basename.hasSuffix(".git") ? String(basename.dropLast(4)) : basename).lowercased()
    }
  }

  enum Constraint: Equatable, Sendable {
    case upToNextMajor(Version)
    case exact(Version)
    case revision(String)
    case latest

    var manifestArgument: String {
      switch self {
      case .upToNextMajor(let version): return "from: \(swiftLiteral(version.description))"
      case .exact(let version): return "exact: \(swiftLiteral(version.description))"
      case .revision(let ref): return "revision: \(swiftLiteral(ref))"
      case .latest: return "\"0.0.0\"..<\"1000000.0.0\""
      }
    }

    var packageArguments: [String] {
      switch self {
      case .upToNextMajor(let version): return ["--from", version.description]
      case .exact(let version): return ["--exact", version.description]
      case .revision(let ref): return ["--revision", ref]
      case .latest: return ["--from", "0.0.0", "--to", "1000000.0.0"]
      }
    }
  }

  var packageLine: String {
    switch dependencyName {
    case .local: return ".package(path: \(swiftLiteral(dependencyName.location)))"
    case .remote:
      return
        ".package(url: \(swiftLiteral(dependencyName.location)), \(constraint.manifestArgument))"
    }
  }

  var productLine: String {
    ".product(name: \(swiftLiteral(importName)), package: \(swiftLiteral(dependencyName.identity)))"
  }

  init?(module: String, comment: String, source: ScriptSource) throws {
    let text = comment.trimmingCharacters(in: .whitespaces)
    let isLocal =
      text.hasPrefix("/") || text.hasPrefix("./") || text.hasPrefix("../") || text.hasPrefix("~/")
    guard isLocal || text.hasPrefix("@") || text.hasPrefix("git@") || text.contains("/") else {
      return nil
    }
    importName = module
    if isLocal {
      let path = absolutePath(text, relativeTo: source.dependencyDirectory)
      var directory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: path.string, isDirectory: &directory),
        directory.boolValue
      else {
        throw SourceError.invalidDependency(text)
      }
      dependencyName = .local(path)
      constraint = .latest
      return
    }
    let markers = ["~>", "=="].compactMap { marker in text.range(of: marker).map { (marker, $0) } }
    let marker = markers.min { $0.1.lowerBound < $1.1.lowerBound }
    let repository: String
    if let (operation, range) = marker {
      repository = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
      let operand = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
      guard !operand.isEmpty, !operand.contains(where: \.isWhitespace) else {
        throw SourceError.invalidConstraint(text)
      }
      if let version = Self.scriptVersion(operand) {
        constraint = operation == "~>" ? .upToNextMajor(version) : .exact(version)
      } else {
        constraint = .revision(operand)
      }
    } else {
      repository = text
      constraint = .latest
    }
    guard !repository.contains(where: \.isWhitespace) else {
      throw SourceError.invalidDependency(repository)
    }
    if repository.hasPrefix("git@"), repository.contains(":") {
      dependencyName = .remote(repository)
    } else if let url = URL(string: repository), let scheme = url.scheme,
      ["https", "http", "ssh"].contains(scheme), url.host != nil
    {
      dependencyName = .remote(repository)
    } else {
      let parts: [String]
      if repository.hasPrefix("@") {
        parts = [String(repository.dropFirst()), module]
      } else {
        parts = repository.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
      }
      guard parts.count == 2,
        parts.allSatisfy({
          !$0.isEmpty
            && $0.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) })
        })
      else {
        throw SourceError.invalidDependency(repository)
      }
      let owner = parts[0].replacingOccurrences(of: ".", with: "-")
      let repo = parts[1].hasSuffix(".git") ? String(parts[1].dropLast(4)) : parts[1]
      dependencyName = .remote("https://github.com/\(owner)/\(repo).git")
    }
  }

  /// Script syntax permits a v prefix and omitted minor or patch components.
  static func scriptVersion(_ operand: String) -> Version? {
    let value = operand.hasPrefix("v") ? String(operand.dropFirst()) : operand
    let coreEnd = value.firstIndex(where: { $0 == "-" || $0 == "+" }) ?? value.endIndex
    let core = value[..<coreEnd].split(separator: ".", omittingEmptySubsequences: false)
    guard (1...3).contains(core.count) else { return nil }
    let normalized = core.map(String.init) + Array(repeating: "0", count: 3 - core.count)
    return Version(normalized.joined(separator: ".") + value[coreEnd...])
  }
}
