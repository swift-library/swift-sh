# Contributing

External contributions are welcome. Use a Conventional Commit PR title and
verify changes with SwiftPM. Maintainers follow the shared
[signing instructions](https://github.com/swift-library/.github/blob/master/MAINTENANCE.md#signing).

## Build And Test

Run the repository checks from the root:

```sh
swift build
swift test
swift build -c release
xcrun swift-format lint --strict --configuration .swift-format --recursive \
  Package.swift Sources Tests Examples \
  Examples/markdown Examples/terminal-rainbow Examples/async-main-count-lines
```

The paths match `format.paths` in [`.github/swift-package.json`](.github/swift-package.json),
which declares the compiler matrix, platforms, and terminal demo for shared CI.
The required checks are `policy / policy` and `validate / result`. The package
requires Swift 6.3, macOS 15 or Linux; macOS source builds require the SDK from
Xcode 26 or newer. See [the terminal demo reference](Documentation/Reference/TerminalDemo.md)
for recording and checking the README example.

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

The [release reference](Documentation/Reference/Release.md) records release facts
and mechanics; version rules are in
[VERSIONING](https://github.com/swift-library/.github/blob/master/VERSIONING.md).
Keep the runtime version, Changelog, dependency lock, and release configuration
aligned. Use the private reporting route in
[SECURITY.md](SECURITY.md) for vulnerabilities.
