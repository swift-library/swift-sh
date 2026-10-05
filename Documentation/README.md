# Documentation

This directory indexes repository-native documentation for `swift-sh`.

## Areas

- `Architecture/`: current architecture truth for the package and runtime
  behavior.
- `Reference/`: command syntax, dependency comment syntax, and supporting
  reference material.

Target-level API documentation belongs with the SwiftPM target it documents,
normally under `Sources/<Target>/<Target>.docc/`. Link to those catalogs from
this index when present, but do not move them under `Documentation/` by default.

## DocC Status

No target-level DocC catalogs are currently checked in. The package exposes the
`swift-sh` executable product only; internal implementation code is not a
documented public SDK.

## Placement Rules

- Put current canonical architecture guidance in `Architecture/`.
- Put supporting reference material in `Reference/`.
- Keep DocC catalogs with their SwiftPM targets; treat `.doccarchive`
  directories as generated output unless this repository explicitly governs
  checked-in documentation archives.
- Keep GitHub-facing governance in `.github/`, not here.
