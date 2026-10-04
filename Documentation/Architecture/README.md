# Architecture

This directory holds current architecture truth for `swift-sh`.

## Documents

- [Runtime Architecture](RuntimeArchitecture.md): how the CLI parses inputs,
  generates cached SwiftPM packages, builds scripts, and executes binaries.

- [Versioning and Release](VersioningAndRelease.md): support, maintenance, and
  immutable release policy.

## Belongs Here

- current package and runtime structure
- current cache and generated package behavior
- current boundaries between CLI, command handling, script parsing, and utility
  support

## Does Not Belong Here

- command syntax tables and examples: `../Reference/`
- unresolved alternatives: `../Proposals/` when that subtree is present
- decision records and cutovers: `../Decisions/` and `../Migrations/` when
  those subtrees are present
- generated documentation output such as `.doccarchive` directories
