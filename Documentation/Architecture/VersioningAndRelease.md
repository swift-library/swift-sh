# Versioning and Release

swift-sh adopts the
[swift-library versioning standard](https://github.com/swift-library/.github/blob/master/VERSIONING.md).
This document records how the package applies it.

## Version Authority

`SwiftSh.version` in `Sources/SwiftSh/SwiftSh.swift` owns the runtime version.
`CHANGELOG.md` owns the matching release notes, and `.github/release.json`
identifies both for `Scripts/validate-version`. A release tag is `vVERSION` and
identifies one clean commit with a matching, nonempty Changelog entry.
Published tags are immutable; source fixes after tagging use a new version. The
default branch is `master`.

During 0.x, fixes and compatible additions increment PATCH, and incompatible
changes increment MINOR with an upgrade note in the Changelog. From 1.0.0,
compatible additions increment MINOR and incompatible changes increment MAJOR.
Compatibility covers command syntax, exit statuses, dependency comment
semantics, cache location, the default build configuration, and compiler and
system requirements. Documentation and CI changes alone do not require a
release.

## Supported Environments

Swift compiler support follows implementation and dependency requirements.
System support is reviewed manually at release time against the organization's
three-generation window. Raising a system minimum is a compatibility change
and is recorded in release notes. Current requirements are Swift 6.3, macOS 15,
and Linux with a supported Swift toolchain.

The newest release line receives maintenance; older-line backports are decided
as needed. Dependabot proposes weekly Swift dependency and Actions updates.
Updates pass compatibility CI before merging. Actions and shared workflows are
pinned to complete commit SHAs.

## Release Acceptance

Read-only CI validates strict formatting, Swift Testing, the Release build,
version consistency, and an independent script consumer. The release workflow
repeats checks on a tag before a separate job receives publishing permission.
Release evidence records the commit, tree, dependency lock, toolchain, system,
validation commands, and logs. Local acceptance covers macOS 27 and remote
candidate and tagged installation. Homebrew distribution is owned by the
organization tap and follows published GitHub Releases.
