# Versioning and Release

Versions are chosen manually and follow SemVer. Compatible fixes advance PATCH;
features advance MINOR. Breaking changes advance MINOR in 0.x and MAJOR from
1.x. Documentation and CI changes alone do not require a release.

`Sources/Sh/Version.swift` owns the runtime version. A release tag is
`vVERSION` and identifies one clean commit with a matching, nonempty Changelog
entry. Published tags are immutable; source fixes after tagging use a new
version. The default branch is `master`.

Swift compiler support follows implementation and dependency requirements.
System support is reviewed manually at release time against the organization's
three-generation window. Raising a system minimum is a compatibility change
and is recorded in release notes. Current requirements are Swift 6.3, macOS 15,
and Linux with a supported Swift toolchain.

The newest release line receives maintenance; older-line backports are decided
as needed. Dependabot proposes weekly Swift dependency and Actions updates.
Updates pass compatibility CI before merging. Actions and shared workflows are
pinned to complete commit SHAs.

Read-only CI validates strict formatting, Swift Testing, the Release build,
version consistency, and an independent script consumer. The release workflow
repeats checks on a tag before a separate job receives publishing permission.
Release evidence records the commit, tree, dependency lock, toolchain, system,
validation commands, and logs. Local acceptance covers macOS 27 and remote
candidate and tagged installation. Homebrew distribution is owned by the
organization tap and follows published GitHub Releases.
