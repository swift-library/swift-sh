// SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
// Copyright (c) 2026 Xudong Xu

import SwiftParser
import SwiftSyntax

/// The dependency directives and entry point style of one script, read from its syntax tree.
struct ScriptAnalysis {
  let source: ScriptSource
  let dependencies: [DependencyDirective]
  let hasMainAttribute: Bool

  init(source: ScriptSource) throws {
    self.source = source
    let visitor = ScriptDeclarations()
    visitor.walk(Parser.parse(source: source.compilableText))
    hasMainAttribute = visitor.hasMainAttribute
    dependencies = try visitor.imports.compactMap { declaration in
      guard let module = declaration.path.first?.name.text else { return nil }
      var trivia = declaration.trailingTrivia
      if let item = declaration.parent?.as(CodeBlockItemSyntax.self), let semicolon = item.semicolon
      {
        trivia += semicolon.trailingTrivia
      }
      for piece in trivia {
        if case .lineComment(let comment) = piece {
          return try DependencyDirective(
            module: module, comment: String(comment.dropFirst(2)),
            baseDirectory: source.dependencyDirectory)
        }
      }
      return nil
    }
  }
}

private final class ScriptDeclarations: SyntaxVisitor {
  var imports: [ImportDeclSyntax] = []
  var hasMainAttribute = false

  init() {
    super.init(viewMode: .sourceAccurate)
  }

  override func visit(_ node: ImportDeclSyntax) -> SyntaxVisitorContinueKind {
    imports.append(node)
    return .skipChildren
  }

  override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
    if node.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "main" {
      hasMainAttribute = true
    }
    return .skipChildren
  }
}
