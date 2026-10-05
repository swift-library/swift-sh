// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SemVer
import Testing

@testable import SwiftSh

struct PackageManifestTests {
  @Test func rendersGoldenManifest() throws {
    let manifest = PackageManifest(
      name: "report 数据",
      targetName: "SwiftShScript_0123456789abcdef",
      entryFile: "Root.swift",
      dependencies: [
        .remote(
          url: "https://github.com/apple/swift-argument-parser.git",
          requirement: .upToNextMajor(from: Version(1, 8, 2))),
        .remote(
          url: "git@example.com:team/markdown.git",
          requirement: .exact(try Version(parsing: "2.0.0-beta.1+build.7"))),
        .remote(url: "https://example.com/tools.git", requirement: .revision("main")),
        .local(path: "/tmp/local package/数据 \\(value)"),
      ],
      products: [
        .init(name: "ArgumentParser", package: "swift-argument-parser"),
        .init(name: "Markdown", package: "markdown"),
        .init(name: "Tools", package: "tools"),
        .init(name: "Local", package: "数据 \\(value)"),
      ],
      macOSDeploymentTarget: "15.0")
    #expect(manifest.rendered() == (try fixture("GeneratedPackage.swift.golden")))
  }

  @Test func rendersEmptyListsWithoutPlatforms() {
    let manifest = PackageManifest(
      name: "hello", targetName: "SwiftShScript_0000000000000000", entryFile: "main.swift")
    let rendered = manifest.rendered()
    #expect(rendered.contains("  dependencies: [],\n"))
    #expect(rendered.contains("      dependencies: [],\n"))
    #expect(!rendered.contains("platforms"))
  }

  @Test func directivesBecomeUniqueManifestEntries() throws {
    let source = ScriptSource(
      path: nil, name: "Script",
      text: """
        import Fixture // @example ~> 1.2
        import Fixture // @example ~> 1.2
        import Other // example/Fixture ~> 1.2
        """,
      dependencyDirectory: absolutePath("."))
    let package = ScriptPackage(
      analysis: try ScriptAnalysis(source: source), cache: ScriptCache(root: absolutePath("cache")))
    #expect(
      package.manifest.dependencies == [
        .remote(
          url: "https://github.com/example/Fixture.git",
          requirement: .upToNextMajor(from: Version(1, 2, 0)))
      ])
    #expect(package.manifest.products.map(\.name) == ["Fixture", "Other"])
  }
}

func fixture(_ name: String) throws -> String {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent()
  return try String(
    contentsOf: root.appendingPathComponent("Fixtures").appendingPathComponent(name),
    encoding: .utf8)
}
