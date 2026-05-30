# Runtime Architecture

## Scope / Purpose

This document describes the current runtime structure for `swift-sh`: how a
script request becomes a generated SwiftPM package, how dependencies are
resolved, and how the final executable is run.

## Context / Boundaries

`swift-sh` is a SwiftPM command line package. The public executable product is
`swift-sh`, backed by the internal `Sh` executable target under `Sources/Sh`.
Tests live in the `ShTests` test target under `Tests/ShTests`.

The package does not publish library products and does not generate
`.xcodeproj` files.

The runtime does not try to become a general Swift parser. It extracts
dependency metadata from import-line comments and delegates package resolution
and compilation to SwiftPM.

## Constraints

- The repository supports Swift 6.3 or newer.
- The package platform floor is macOS 14.
- Script dependencies are expressed as SwiftPM package requirements generated
  from import comments.
- Local dependency paths are resolved relative to the script path when the
  script is file-backed.

## Current Structure

- `swift-sh` parses command-line arguments into modes such as run, package,
  open, cache clean, and help.
- Run mode reads a file, stdin, or named pipe, strips the shebang for generated
  source where needed, detects `@main`, and collects import specifications.
- Script execution writes a generated SwiftPM package under the `swift-sh`
  cache directory, writes `deps.json` for dependency cache comparison, builds
  with `swift build`, then replaces the process with the generated executable.
- File-backed scripts use a cache directory derived from the resolved script
  path hash. Stdin and named-pipe inputs use stable synthetic names.
- File-backed script rebuild checks compare the executable mtime against the
  script and any local dependency files.
- Package mode creates a standalone SwiftPM package from the script with
  SwiftPM CLI commands. It copies the original script by default and moves it
  only when `--move` is provided.
- Open mode writes the generated package first, then opens either the generated
  source in `$EDITOR` or, on macOS, the generated SwiftPM package in Xcode. It
  does not generate `.xcodeproj` files.

## Cache Locations

`XDG_CACHE_HOME` overrides the parent cache location. If it is unset:

- macOS uses `$HOME/Library/Developer/swift-sh.cache`
- Linux uses `$HOME/.cache/swift-sh`

## Key Principles

- Keep the user-facing script as the source of truth.
- Let SwiftPM own dependency resolution, build planning, and compilation.
- Avoid rewriting generated manifests when dependency specifications have not
  changed.
- Preserve script line numbers when removing a shebang from stdin-backed source.

## Cross-cutting Concerns

- Import comments are a compatibility contract; changes should update
  `../Reference/ImportSpecifications.md`.
- Command behavior is a user contract; changes should update
  `../Reference/Commands.md`.
- Dependency and toolchain support changes should keep `Package.swift`,
  `Package.resolved`, CI, and README badges aligned.

## Risks / Known Gaps

- Import extraction is regex-based and intentionally incomplete compared to a
  full Swift parser.
- Unversioned dependency comments resolve to a broad latest-version range. This
  is a single-file script convenience rather than a reproducibility guarantee.
- The package exposes the `swift-sh` executable product only; implementation
  code lives in the `Sh` executable target.
- Target-level DocC catalogs are not currently present.

## Related Decisions

No decision records are currently maintained. Add
`Documentation/Decisions/README.md` and individual decision records if this
repository starts recording architectural history.
