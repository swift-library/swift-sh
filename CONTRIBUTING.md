# Contributing

Keep changes small, role-aware, and verified with SwiftPM.

## Build And Test

Use SwiftPM from the repository root:

```sh
swift --version
swift package resolve
swift-format lint --strict --configuration .swift-format \
  Package.swift \
  $(find Sources Tests Examples -type f \( -name '*.swift' -o ! -name '*.*' \) -print)
swift build
swift test
```

The package currently targets Swift 6.3 or newer and macOS 14 or newer.

## Documentation Placement

- Route instructions belong in `AGENTS.md`.
- Public entry points and common user workflows belong in `README.md`.
- Documentation navigation belongs in `Documentation/README.md`.
- Current architecture truth belongs in `Documentation/Architecture/*`.
- Command, import, and troubleshooting reference belongs in
  `Documentation/Reference/*`.
- GitHub-specific workflows and collaboration files belong in `.github/*`.
- Target-level API documentation, when added, belongs beside the SwiftPM target
  it documents, normally at `Sources/<Target>/<Target>.docc/`.

## Change Discipline

- Keep root `README.md` concise and outward-facing.
- Link to deeper reference or architecture material instead of duplicating it.
- Keep `Package.swift`, `Package.resolved`, and CI in agreement when changing
  dependencies or toolchain support.
