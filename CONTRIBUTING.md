# Contributing

Keep changes small, role-aware, and verified with SwiftPM.

## Build And Test

Run the repository checks from the root:

```sh
Scripts/check
```

This validates strict formatting, release metadata, Swift tests, a Release
build, and an independent script consumer. CI validates the minimum supported
Swift toolchain with its matching SDK. The package requires Swift 6.3, macOS 15
or Linux; macOS source builds require the SDK from Xcode 26 or newer.

For a custom SwiftPM scratch directory, set `SWIFT_SH_TEST_BINARY` to its built
swift-sh executable before running the integration tests. Tests use isolated
script packages, caches, and local Git repositories, so they need `git` but no
network access.

## Documentation Placement

- Route instructions belong in `AGENTS.md`.
- Public entry points and common user workflows belong in `README.md`.
- Documentation navigation belongs in `Documentation/README.md`.
- Current architecture truth belongs in `Documentation/Architecture/*`.
- Command, dependency comment, and troubleshooting reference belongs in
  `Documentation/Reference/*`.
- GitHub-specific workflows and collaboration files belong in `.github/*`.
- Target-level API documentation, when added, belongs beside the SwiftPM target
  it documents, normally at `Sources/<Target>/<Target>.docc/`.

## Change Discipline

- Keep root `README.md` concise and outward-facing.
- Link to deeper reference or architecture material instead of duplicating it.
- Keep `Package.swift`, `Package.resolved`, and CI in agreement when changing
  dependencies or toolchain support.

## Releases and Security

The [version policy](Documentation/Architecture/VersioningAndRelease.md) owns
release and maintenance rules. Keep the runtime version, Changelog, dependency
lock, and release configuration aligned. Use the private reporting route in
[SECURITY.md](SECURITY.md) for vulnerabilities.
