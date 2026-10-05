# Dependency Comments

`swift-sh` reads dependencies from trailing line comments on Swift import
declarations. Imports may span lines or use attributes; comments
and string literals are ignored by the syntax analyzer.

```swift
import ModuleName  // dependency constraint
```

Only direct dependencies need comments. Transitive dependencies are resolved by
SwiftPM.

## GitHub Owner Shorthand

Use `@owner` when the module name and repository name match:

```swift
import ExampleKit  // @example
```

This resolves to `https://github.com/example/ExampleKit.git`.

GitHub usernames or organization names with dots are normalized to hyphens to
match GitHub behavior.

## Explicit GitHub Repository

Use `owner/repository` when the module name differs from the repository name:

```swift
import Markdown  // swiftlang/swift-markdown == 0.8.0
```

## Full URLs

HTTPS, SSH URL, common SCP-style, and `file://` Git URLs are supported:

```swift
import Charts    // https://example.com/charts.git ~> 2
import Charts    // git@example.com:team/charts.git ~> 2
import Charts    // ssh://git@example.com/team/charts.git ~> 2
import Fixtures  // file:///srv/git/fixtures.git ~> 1
```

## Local Dependencies

Local dependencies must expose library products in their `Package.swift`.

```swift
import Parsing   // ./Packages/Parsing
import Shared    // ../shared
import Toolkit   // ~/Developer/toolkit
import Fixtures  // /srv/packages/fixtures
```

Relative local paths resolve beside the resolved source file for file-backed
scripts, or against the current working directory for stdin and named pipes.
Local paths can contain spaces and must identify an existing package directory.
A value like `foo/bar` is treated as a GitHub dependency; prefix local relative
paths with `./` or `../`.

Local dependencies do not need version constraints. A cached build is rebuilt
when the content of any non-hidden file in a local dependency changes.

## Version Constraints

`~>` maps to SwiftPM's up-to-next-major requirement:

```swift
import ArgumentParser  // apple/swift-argument-parser ~> 1.8
```

Major-only and major/minor versions are padded with zero components. A leading
`v` is accepted. `~> 0.2` means `0.2.0..<1.0.0`, matching SwiftPM next-major
semantics. Strict SemVer validation applies after adaptation, including numeric
leading-zero rules. A value that is not a semantic version is a Git revision;
both operators retain that fallback.

`==` with a semantic version maps to an exact version:

```swift
import Markdown  // swiftlang/swift-markdown == 0.8.0
```

`==` with a non-version value maps to a revision:

```swift
import ExampleKit  // example/ExampleKit == b4de8c12
```

## Imports Without A Constraint

```swift
import ExampleKit  // @example
```

The first build lists the repository's tags with `git ls-remote` and selects
the newest release: a tag that is a semantic version, with or without a `v`
prefix, and not a prerelease. The generated package depends on that release
with SwiftPM's `from:` requirement, so it accepts later releases up to the next
major version, like `~>`.

swift-sh records the selected release beside the cached build. Later runs use
the record without a network request, so the script keeps building against the
same release. `swift sh cache clean`, for the script or the whole cache, discards
the record, and the next build selects again. A repository without release tags
fails with a request to add a constraint, such as `== main` or `~> 1.0`.

`swift sh package` selects the newest release the same way and passes it to
SwiftPM as the dependency's lower bound.

Use an explicit `~>` or `==` constraint when a script must build against the
same versions everywhere.

## Pre-release Versions

Pre-release versions are only fetched when specified explicitly:

```swift
import Preview  // @example ~> 1.0.0-alpha.1
import Nightly  // @example == 1.0.0-alpha.1
```

## Testable And Specific Imports

`@testable import` is supported:

```swift
@testable import ExampleKit  // @example ~> 1.0
```

Specific import forms resolve the product from the imported module name:

```swift
import struct Foo.Bar  // https://example.com/example/Bar.git ~> 1.0
```

## Conditional Compilation

Dependencies from all syntactic `#if` branches are collected. swift-sh does
not evaluate custom compilation conditions or choose platform-specific package
requirements. The script's compiler still controls which Swift code is active.

Imports must name an exported library product. Product-to-module renaming is
outside the dependency comment syntax.
