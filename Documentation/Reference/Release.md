# Release

[`.github/swift-package.json`](../../.github/swift-package.json) declares package
validation. The callers in `.github/workflows/` pin the shared validation,
policy, and release workflows from `swift-library/github-workflows`.

Version rules for swift-sh, covering tags, release timing, choosing the
next version and the changelog, are in
[VERSIONING](https://github.com/swift-library/.github/blob/master/VERSIONING.md).
This document records the repository's release facts and mechanics and does
not restate those rules.

## Components and Version Sources

| Shipped component | Version meaning | Version source | Mirrors and derived fields | Update and read-only check |
| --- | --- | --- | --- | --- |
| `swift-sh` executable | Runtime version | `SwiftSh.version` in `Sources/SwiftSh/SwiftSh.swift`, named by `version_file` in [`.github/release.json`](../../.github/release.json) | `CHANGELOG.md` records release notes. | The shared version validator checks the declaration and changelog; `swift test` checks CLI version output. |

## Compatibility Surface

Compatibility covers command syntax, exit statuses, dependency comment
semantics, cache location, the default build configuration, and compiler and
system requirements.

## Dependencies and Verified Combinations

The package requires Swift 6.3, macOS 15 or Linux with a supported toolchain.
The maintained macOS window is 15/26/27. CI tests macOS 15 with Xcode 26.0.1 and
Swift 6.3.3, macOS 26 with Xcode 26.6, and Linux with the digest-pinned Swift
6.3.3 Ubuntu image. Strict formatting runs on the last declared compiler.
Local acceptance also covers native macOS 27.

## Validation

Run `swift build`, `swift test`, `swift build -c release`, and strict
`swift-format` lint over the declared paths. The exact local commands are in
[CONTRIBUTING.md](../../CONTRIBUTING.md).

Tests cover CLI version/help, usage errors, argument forwarding, and script
execution with local and tagged Git dependencies. The shared demo job builds
the release executable and checks the [terminal recording](TerminalDemo.md).
The required checks are `policy / policy` and `validate / result`.

## Acceptance and Publication

The [`Release` workflow](../../.github/workflows/release.yml) runs when a `v*`
tag is pushed. It validates the tagged commit, then verifies the signed
annotated tag, version declaration, and changelog before publishing the release
notes. Its accepted commit is the same commit that validation checked.

Homebrew distribution is owned by the organization tap and follows published
GitHub Releases. Repository-specific security reporting is in `SECURITY.md`.
