# Versioning and Release

swift-sh follows the [shared release standard](https://github.com/swift-library/.github/blob/master/VERSIONING.md).
`SwiftSh.version` in `Sources/SwiftSh/SwiftSh.swift` declares the runtime version.
`CHANGELOG.md` records release notes, and `.github/release.json` selects validation.

## Compatibility surface

Compatibility covers command syntax, exit statuses, dependency comment
semantics, cache location, the default build configuration, and compiler and
system requirements.

## Requirements and validation

The package requires Swift 6.3, macOS 15 or Linux with a supported toolchain.
The maintained macOS window is 15/26/27. CI tests macOS 15 and 26 and Linux
with the digest-pinned Swift 6.3.3 Ubuntu image. Strict formatting runs separately.
Local acceptance also covers native macOS 27.

`Scripts/check` runs formatting, Swift tests, a release build and an independent
script consumer. `Scripts/check-consumer` accepts a remote repository and a
revision or version to verify fresh CLI installation. It checks version/help,
argument errors and a script using a remote SemVer dependency.
Evidence belongs in `.build/release-validation`.

Homebrew distribution is owned by the organization tap and follows published
GitHub Releases. Repository-specific security reporting is in `SECURITY.md`.
