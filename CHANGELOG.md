# Changelog

## 0.1.0

- Run file, stdin and named-pipe Swift scripts with inline SwiftPM dependencies.
- Analyze imports and entry attributes using official SwiftParser and SwiftSyntax, preserving source diagnostics and shebang line numbers.
- Support version conveniences and Git revisions through SemVer while keeping `~>` up-to-next-major requirements.
- Use official Swift Subprocess, Swift System and platform SHA-256 implementations; serialize concurrent cache builds and invalidate changed source, manifests, local dependencies and toolchains.
- Expose `--version`, package scripts with copy or move semantics, open generated packages, and clean script caches.
- Support spaces and Unicode in source, dependency, cache and executable paths; report unsupported SwiftPM build paths before generation.
- Require Swift 6.3 and macOS 15, with Linux compatibility verified separately.
