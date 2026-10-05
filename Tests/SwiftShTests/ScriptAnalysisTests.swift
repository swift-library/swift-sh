// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import Foundation
import SemVer
import SystemPackage
import Testing

@testable import SwiftSh

struct ScriptAnalysisTests {
  @Test(arguments: [
    "import Fixture // @example ~> 1.2",
    "@testable import Fixture // @example ~> 1.2",
    "import\n Fixture // @example~>v1.2",
    "import struct Fixture.Value // @example ~> 1.2.0",
    "import func Fixture.value // @example ~> 1.2",
    "import Fixture; // @example ~> 1.2",
  ])
  func syntaxNodesIdentifyModules(_ text: String) throws {
    let analysis = try ScriptAnalysis(source: source(text))
    let dependency = try #require(analysis.dependencies.first)
    #expect(analysis.dependencies.count == 1)
    #expect(dependency.module == "Fixture")
    #expect(dependency.source.location == "https://github.com/example/Fixture.git")
    #expect(dependency.requirement == .upToNextMajor(Version(1, 2, 0)))
  }

  @Test func commentsAndStringsAreNotDeclarations() throws {
    let analysis = try ScriptAnalysis(
      source: source(
        #"""
        /* import Fake // @example
           /* @main */
        */
        // import Fake // @example
        let text = "import Fake // @example @main"
        let multiline = """
        @main
        import Fake // @example
        """
        let raw = #"import Fake // @example @main"#
        import Foundation // Standard library
        """#))
    #expect(analysis.dependencies.isEmpty)
    #expect(!analysis.hasMainAttribute)
  }

  @Test func declarationAttributesAndConditionalBoundary() throws {
    let analysis = try ScriptAnalysis(
      source: source(
        """
        #if os(macOS)
        import Foo // example/swift-foo == 1.2.3-alpha.1+build
        #else
        import Bar // example/swift-bar == main
        #endif
        @main /* entry point */
        struct Program { static func main() {} }
        """))
    #expect(analysis.hasMainAttribute)
    #expect(analysis.dependencies.map(\.module) == ["Foo", "Bar"])
    #expect(
      analysis.dependencies[0].requirement == .exact(try Version(parsing: "1.2.3-alpha.1+build")))
    #expect(analysis.dependencies[1].requirement == .revision("main"))
  }

  @Test(arguments: [
    ("example/swift-fixture", "https://github.com/example/swift-fixture.git"),
    ("@some.owner", "https://github.com/some-owner/Fixture.git"),
    ("https://example.com/fixture.git", "https://example.com/fixture.git"),
    ("ssh://git@example.com/fixture.git", "ssh://git@example.com/fixture.git"),
    ("git@example.com:fixture.git", "git@example.com:fixture.git"),
    ("file:///srv/git/fixture.git", "file:///srv/git/fixture.git"),
  ])
  func repositoryForms(_ comment: String, location: String) throws {
    let dependency = try #require(try directive(comment))
    #expect(dependency.source.location == location)
    #expect(dependency.requirement == .unspecified)
  }

  @Test(arguments: [
    "", "@", "@bad!", "owner/repo ==", "owner/repo ~>", "owner/repo >= 1.0",
    "owner/repo == 1.0 extra",
  ])
  func malformedDeclarations(_ comment: String) throws {
    if comment.isEmpty {
      #expect(try directive(comment) == nil)
    } else {
      #expect(throws: SourceError.self) { try directive(comment) }
    }
  }

  @Test(arguments: [
    ("1", "1.0.0"), ("v1.2", "1.2.0"), ("0.2.3-alpha.1+build", "0.2.3-alpha.1+build"),
  ])
  func scriptVersionConveniences(_ operand: String, version: String) {
    #expect(Version(lenient: operand)?.description == version)
    #expect(Version("v1.2") == nil)
  }

  @Test(arguments: ["main", "abcdef", "01.2.3", "1.2.3-alpha.01"])
  func nonVersionsAreGitReferences(_ operand: String) throws {
    let dependency = try #require(try directive("@example == " + operand))
    #expect(dependency.requirement == .revision(operand))
  }

  @Test func localPathsAndLiteralEscaping() throws {
    let temporary = try TemporaryDirectory()
    let dependency = temporary.path.appending("local \"quoted\"")
    try FileManager.default.createDirectory(
      at: fileURL(dependency), withIntermediateDirectories: true)
    let parsed = try #require(
      try directive("./local \"quoted\"", relativeTo: temporary.path))
    #expect(parsed.source == .local(dependency))
    let manifest = PackageManifest(
      name: "script", targetName: "Script", entryFile: "main.swift",
      dependencies: [try parsed.manifestDependency(releases: [:])])
    #expect(manifest.rendered().contains("local \\\"quoted\\\""))
    #expect(swiftLiteral("\\(value)\n\"quoted\"") == "\"\\\\(value)\\n\\\"quoted\\\"\"")
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    #expect(try directive("~/", relativeTo: temporary.path)?.source == .local(FilePath(home)))
  }

  @Test func shebangPreservesLinesAndLiteralContent() {
    let input = source(
      "#!/usr/bin/swift sh\r\n@main struct Program {\n  static func main() { print(\"#!inside\") }\n}\n"
    )
    #expect(
      input.compilableText
        == "// swift-sh script\n@main struct Program {\n  static func main() { print(\"#!inside\") }\n}\n"
    )
    #expect(
      input.compilableText.utf8.filter { $0 == 10 }.count
        == input.text.utf8.filter { $0 == 10 }.count)
  }
}

private func directive(
  _ comment: String, relativeTo directory: FilePath = absolutePath(".")
) throws -> DependencyDirective? {
  try DependencyDirective(module: "Fixture", comment: comment, baseDirectory: directory)
}

extension DependencyDirective {
  fileprivate var requirement: Requirement? {
    guard case .remote(_, let requirement) = source else { return nil }
    return requirement
  }
}

private func source(_ text: String) -> ScriptSource {
  ScriptSource(
    path: nil, name: "Script", text: text,
    dependencyDirectory: absolutePath(FileManager.default.currentDirectoryPath))
}
