# Changelog

## 0.2.0

### Upgrade notes

- swift-sh is licensed under the Apache License 2.0 with the Swift Runtime Library Exception. Releases 0.1.0 and 0.1.1 keep their original license.
- Scripts build in release configuration. Place `--debug` before the script path to build and run a debug binary.
- An import whose dependency comment has no version builds against the repository's newest release tag. The first build selects it and later builds keep it until `swift sh cache clean`. Add a version to the comment to choose one explicitly.
- Builds live in `~/Library/Caches/swift-sh` on macOS, `~/.cache/swift-sh` on Linux, or `$XDG_CACHE_HOME/swift-sh` when it holds an absolute path. `swift sh cache clean` also removes the cache directory that earlier releases used on macOS.

### Added

- `swift sh run <script>` names the default command, for scripts whose path is also a command name.
- Dependency comments accept `file://` Git URLs.

### Fixed

- Editing a local dependency rebuilds the script even when file modification times do not change, because local dependencies are fingerprinted by content.
- Replacing the Swift toolchain within the same second as the previous build is detected.

### Dependencies

- Swift Argument Parser 1.8.2 and SwiftSyntax 604.

## 0.1.1

- Report a script path that does not exist, naming the path and exiting with status 2, instead of running piped standard input as the script. Standard input is read as the script only for `swift sh -`, `swift sh --`, or `swift sh` with no arguments.

## 0.1.0

- Run file, stdin and named-pipe Swift scripts with inline SwiftPM dependencies.
- Analyze imports and entry attributes using official SwiftParser and SwiftSyntax, preserving source diagnostics and shebang line numbers.
- Support version conveniences and Git revisions through SemVer while keeping `~>` up-to-next-major requirements.
- Use official Swift Subprocess, Swift System and platform SHA-256 implementations; serialize concurrent cache builds and invalidate changed source, manifests, local dependencies and toolchains.
- Expose `--version`, package scripts with copy or move semantics, open generated packages, and clean script caches.
- Support spaces and Unicode in source, dependency, cache and executable paths; report unsupported SwiftPM build paths before generation.
- Require Swift 6.3 and macOS 15, with Linux compatibility verified separately.
