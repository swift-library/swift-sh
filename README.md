# `swift sh` ![badge-platforms] ![badge-languages]

`swift-sh` runs single-file Swift scripts with SwiftPM dependencies declared
next to their `import` statements.

```swift
#!/usr/bin/swift sh
import Collections  // apple/swift-collections ~> 1.2
print(Deque(["Hi", "from", "swift-sh"]))
```

Save this as `hello.swift` and run `swift sh hello.swift`. The script is analyzed
with SwiftParser, built in a cached SwiftPM package, and executed with its
arguments, working directory, standard streams, and exit status preserved.

## Requirements

- Swift 6.3 or newer
- macOS 15 or newer, or Linux with a supported Swift toolchain
- Building on macOS requires the macOS SDK from Xcode 26 or newer

CI validates macOS 15 and 26 and Ubuntu 22.04 with Swift 6.3. Local release
validation also covers macOS 27. Compiler requirements and system deployment
versions are maintained separately.

## Installation

```sh
brew install swift-library/tap/swift-sh
swift sh --version
```

The organization tap is
[swift-library/homebrew-tap](https://github.com/swift-library/homebrew-tap).
To build a release from source:

```sh
git clone --branch v0.1.0 https://github.com/swift-library/swift-sh.git
cd swift-sh
swift build -c release --force-resolved-versions
```

Put the resulting `swift-sh` executable on `PATH`. Swift then invokes it as
`swift sh`.

## Commands

```text
swift sh <script> [arguments]
swift sh - [arguments]
swift sh -- [arguments]
swift sh package <script> [--force] [--move]
swift sh open <script> [--xcode]
swift sh cache clean [<script>]
swift sh --version
```

Arguments after a script path or an explicit stdin marker are passed to the
script. Scripts may use top-level statements or an `@main` entry point.

`package` creates a standalone SwiftPM package beside the script. `open` opens
the generated source in `$EDITOR`, or its package in Xcode with `--xcode`.
`cache clean` removes all generated builds, or one file's build when given a
script path. See the [command reference](Documentation/Reference/Commands.md)
for input handling, packaging behavior, and exit codes.

## Dependencies

```swift
import ExampleKit      // @example
import ArgumentParser  // apple/swift-argument-parser ~> 1.8
import Markdown        // swiftlang/swift-markdown == 0.8.0
import Foo             // ./my/project
```

Only direct dependencies need comments. Versions support abbreviated numbers,
a `v` prefix, and prerelease identifiers; `~>` uses SwiftPM's next-major range.
Use explicit versions for repeatable scripts. Local paths resolve beside a
file-backed script, or against the current directory for streamed input.

The [import reference](Documentation/Reference/ImportSpecifications.md) covers
repository forms, versions, member imports, and conditional compilation.

## Examples and Documentation

- [Terminal Rainbow](Examples/terminal-rainbow)
- [Swift Markdown](Examples/markdown)
- [Async entry point](Examples/async-main-count-lines)
- [Documentation index](Documentation/README.md)
- [Runtime architecture](Documentation/Architecture/RuntimeArchitecture.md)
- [Contributing](CONTRIBUTING.md)
- [Security reports](SECURITY.md)
- [Changelog](CHANGELOG.md)

## Maintenance and License

The latest release line receives maintenance. Dependencies and GitHub Actions
are checked weekly through pull requests and compatibility CI. Versions follow
SemVer: breaking changes in 0.x advance the minor version. See the
[version policy](Documentation/Architecture/VersioningAndRelease.md).

`swift-sh` is distributed under the [Unlicense](LICENSE.md). [NOTICE](NOTICE)
records source ownership, provenance, and separately licensed release tooling.

[badge-platforms]: https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey.svg
[badge-languages]: https://img.shields.io/badge/swift-6.3-orange.svg
