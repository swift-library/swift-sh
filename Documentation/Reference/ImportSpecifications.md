# Import Specifications

`swift-sh` reads dependency specifications from trailing line comments on
Swift import declarations. Imports may span lines or use attributes; comments
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

HTTPS, SSH URL, and common SCP-style Git URLs are supported:

```swift
import BumbleButt  // https://example.com/bb.git ~> 9
import CommonTaDa  // git@github.com:example/tada.git ~> 1
import TaDa        // ssh://git@github.com:example/tada.git ~> 1
```

## Local Dependencies

Local dependencies must expose library products in their `Package.swift`.

```swift
import Foo  // ./my/project
import Bar  // ../my/other/project
import Baz  // ~/my/other/other/project
import Fuz  // /I/have/many/projects
```

Relative local paths resolve beside the resolved source file for file-backed
scripts, or against the current working directory for stdin and named pipes.
Local paths can contain spaces and must identify an existing package directory. A value like `foo/bar` is treated as a GitHub dependency; prefix local
relative paths with `./` or `../`.

Local dependencies do not need version constraints.

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

If no constraint is provided, `swift-sh` requests a broad SwiftPM version range:

```swift
import ExampleKit  // @example
```

This is a deliberate single-file script convenience, not a reproducibility
guarantee. It is suitable for temporary scripts where following newer versions
is acceptable. Prefer explicit `~>` or `==` constraints for repeatable scripts.
Fully reproducible dependency resolution would require a sidecar lockfile, which
is outside the current single-file model.

## Pre-release Versions

Pre-release versions are only fetched when specified explicitly:

```swift
import Floibles  // @example ~> 1.0.0-alpha.1
import Bloibles  // @example == 1.0.0-alpha.1
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
