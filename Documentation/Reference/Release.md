# Release

Release status: partly manual; `.github/release.json` selects validation and
`Scripts/check` runs local acceptance.

Version rules for swift-sh, covering tags, release timing, choosing the
next version and the changelog, are in
[VERSIONING](https://github.com/swift-library/.github/blob/master/VERSIONING.md).
This document records the repository's release facts and mechanics and does
not restate those rules.

## Components and Version Sources

| Shipped component | Version meaning | Version source | Mirrors and derived fields | Update and read-only check |
| --- | --- | --- | --- | --- |
| `swift-sh` executable | Runtime version | `SwiftSh.version` in `Sources/SwiftSh/SwiftSh.swift`, named by `version_file` in [`.github/release.json`](../../.github/release.json) | `CHANGELOG.md` records release notes. | `Scripts/check-consumer` checks the runtime version against the source declaration. |

## Compatibility Surface

Compatibility covers command syntax, exit statuses, dependency comment
semantics, cache location, the default build configuration, and compiler and
system requirements.

## Dependencies and Verified Combinations

The package requires Swift 6.3, macOS 15 or Linux with a supported toolchain.
The maintained macOS window is 15/26/27. CI tests macOS 15 and 26 and Linux
with the digest-pinned Swift 6.3.3 Ubuntu image. Strict formatting runs separately.
Local acceptance also covers native macOS 27.

## Derived Metadata and Drift Checks

`Scripts/check` runs formatting, Swift tests, a release build and an independent
script consumer. `Scripts/check-consumer` checks version/help, argument errors
and a script using a remote SemVer dependency.

## Candidate, Acceptance and Publication

`Scripts/check-consumer` accepts a remote repository and a revision or version
to verify fresh CLI installation.

Homebrew distribution is owned by the organization tap and follows published
GitHub Releases. Repository-specific security reporting is in `SECURITY.md`.

## Evidence Reuse and Invalidation

Evidence belongs in `.build/release-validation`.

## Entry Points and Artifact Retention

| Operation | Existing command or explicit manual procedure | Required access |
| --- | --- | --- |
| Version update and check | `Scripts/check-consumer` checks the runtime version against the source declaration. | Not established. |
| Candidate validation and build | `Scripts/check` | Not established. |
| Status and interrupted-run recovery | Not established. | Not established. |
| Acceptance and publication | Run [`Release`](../../.github/workflows/release.yml) with the accepted tag; it validates the tag and publishes the GitHub release. `Scripts/check-consumer` verifies fresh CLI installation; Homebrew distribution is owned by the organization tap and follows published GitHub Releases. | Repository write access to run workflows |
| Cleanup | Not established. | Not established. |
