// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import SemVer

/// The `Package.swift` of a generated script package. Every value reaches the rendered manifest
/// as an escaped Swift string literal.
struct PackageManifest: Equatable, Sendable {
  var name: String
  var targetName: String
  var entryFile: String
  var dependencies: [Dependency] = []
  var products: [Product] = []
  /// The `major.minor` macOS version to build for; nil leaves the SwiftPM default.
  var macOSDeploymentTarget: String?

  enum Dependency: Equatable, Sendable {
    case remote(url: String, requirement: Requirement)
    case local(path: String)
  }

  enum Requirement: Equatable, Sendable {
    case upToNextMajor(from: Version)
    case exact(Version)
    case revision(String)
  }

  struct Product: Equatable, Sendable {
    var name: String
    var package: String
  }

  static let toolsVersion = "6.3"

  func rendered() -> String {
    var lines = [
      "// swift-tools-version:\(Self.toolsVersion)",
      "import PackageDescription",
      "",
      "let package = Package(",
      "  name: \(swiftLiteral(name)),",
    ]
    if let macOSDeploymentTarget {
      lines.append("  platforms: [.macOS(\(swiftLiteral(macOSDeploymentTarget)))],")
    }
    lines += [
      "  products: [",
      "    .executable(name: \(swiftLiteral(name)), targets: [\(swiftLiteral(targetName))])",
      "  ],",
    ]
    lines += list("dependencies", dependencies.map(\.rendered), indent: "  ")
    lines += [
      "  targets: [",
      "    .executableTarget(",
      "      name: \(swiftLiteral(targetName)),",
    ]
    lines += list(
      "dependencies",
      products.map {
        ".product(name: \(swiftLiteral($0.name)), package: \(swiftLiteral($0.package)))"
      },
      indent: "      ")
    lines += [
      "      path: \".\",",
      "      sources: [\(swiftLiteral(entryFile))]",
      "    )",
      "  ],",
      "  swiftLanguageModes: [.v6]",
      ")",
      "",
    ]
    return lines.joined(separator: "\n")
  }

  private func list(_ label: String, _ elements: [String], indent: String) -> [String] {
    guard !elements.isEmpty else { return ["\(indent)\(label): [],"] }
    return ["\(indent)\(label): ["] + elements.map { "\(indent)  \($0)," } + ["\(indent)],"]
  }
}

extension PackageManifest.Dependency {
  fileprivate var rendered: String {
    switch self {
    case .local(let path):
      return ".package(path: \(swiftLiteral(path)))"
    case .remote(let url, let requirement):
      return ".package(url: \(swiftLiteral(url)), \(requirement.rendered))"
    }
  }
}

extension PackageManifest.Requirement {
  fileprivate var rendered: String {
    switch self {
    case .upToNextMajor(let version): return "from: \(swiftLiteral(version.description))"
    case .exact(let version): return "exact: \(swiftLiteral(version.description))"
    case .revision(let reference): return "revision: \(swiftLiteral(reference))"
    }
  }
}
