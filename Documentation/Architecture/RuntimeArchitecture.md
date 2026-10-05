# Runtime Architecture

## Scope

`swift-sh` is the sole public SwiftPM product. Its implementation lives in the
internal `SwiftSh` executable target; `SwiftShTests` validates syntax, command
routing, generated packages, and end-to-end behavior using Swift Testing.

## Dependencies and Ownership

Swift Argument Parser owns command parsing and help. SwiftParser and SwiftSyntax
own Swift syntax recognition. Swift System supplies paths and file descriptors,
Foundation supplies file operations and input handles, and Swift Subprocess
owns asynchronous SwiftPM and Git execution. SemVer owns strict version
parsing; script-specific abbreviations and revision fallback belong to
SwiftSh. SHA-256 uses CryptoKit on macOS and Swift Crypto on Linux.

The package uses Swift 6.3 and supports macOS 15 and Linux. Its macOS source
build needs the SDK from Xcode 26 or newer for Swift Subprocess. Dependency
ranges and `Package.resolved` constrain the supported compiler line.

## Commands

`SwiftSh` is the root `AsyncParsableCommand`. Its subcommands are `run`,
`package`, `open`, and `cache clean`; `run` is hidden and is the default, so
`swift sh <script>` reaches it. `RunCommand` captures the script and its
arguments for passthrough, so flags after the script are never parsed. Only
`--debug` is recognized before the script. Help and version are recognized only
as the sole argument or as the first argument of the default command.

The root command maps outcomes to exit statuses: help and version print to
stdout and exit with 0, parse and validation errors print `error: invalid usage`
and the usage text to stderr and exit with 3, and other failures print
`error:` and their description and exit with 2.

## Input and Analysis

`ScriptSource` reads a file, stdin, or named pipe once into a UTF-8 snapshot.
It owns the resolved source identity and directory for relative dependencies.
A leading shebang becomes a comment on the same line; script contents and
subsequent diagnostic line numbers are preserved.

`ScriptAnalysis` walks real syntax nodes to collect imports, their trailing
line comments, `@testable` attributes, and `@main` attributes. Comments and
string literals cannot create declarations. Both branches of conditional
compilation are collected; condition evaluation remains the compiler's
responsibility.

`DependencyDirective` parses one import comment into the imported module and a
source: a remote Git URL with a requirement, or a local package path. Remote
requirements are up-to-next-major, exact, revision, or unspecified. The
imported module name must identify an exported library product.

## Generated Package and Cache

`ScriptPackage` writes a generated source copy and a `Package.swift` rendered
from `PackageManifest`, a structured model whose strings are always emitted as
escaped Swift literals. Top-level code uses `main.swift`; attributed entry
points use `Root.swift`. Switching entry forms removes the previous generated
entry. Generated writes preserve the user-owned source file, including when an
old cache entry is a symbolic link. On macOS the generated package uses the
current host system version as its deployment target. Its private target uses
an ASCII name computed from the cache identity, keeping linker entry symbols
portable. The executable retains the script's name.

`ReleaseSelection` serves unspecified remote requirements. It lists the
repository's tags with `git ls-remote --tags --refs`, with terminal prompts
disabled, and chooses the newest semantic version tag that is not a
prerelease. `ScriptPackage` stores the selections in `.release-selection.json`
beside the generated package and renders them as `from:` requirements. Stored
selections are reused without network access until the cache entry is removed.

`ScriptCache` uses SHA-256 identities. File inputs key by their resolved path;
stream inputs key by source contents, input kind, and dependency directory.
An absolute `XDG_CACHE_HOME` sets the parent cache directory. Otherwise macOS
uses `$HOME/Library/Caches/swift-sh` and Linux uses `$HOME/.cache/swift-sh`.
Cleaning the whole default macOS cache also removes the locations used before
0.2.0 under `$HOME/Library/Developer`.

Builds use release configuration unless `--debug` selects debug. Release builds
of scripts with `@testable` imports add `-enable-testing`. Each configuration
has a build record holding the SwiftPM arguments, hashes of the generated
source and manifest, the toolchain fingerprint, and a hash of the paths and
contents of the non-hidden files in every local dependency. A changed record or
a missing binary triggers a build.

Process locks serialize generation and builds for one cache key. Shared locks
allow separate scripts to build concurrently and coordinate with whole-cache
cleaning. Lock files live outside removable cache directories; descriptors
close when the process is replaced.

## Toolchain and Execution

`SwiftToolchain` resolves `swift` from `PATH`, resolves the macOS system shim
with `xcrun`, and verifies Swift 6.3 or newer once per fingerprint. The
fingerprint covers the compiler path, its size, sub-second modification time,
device and inode, the host system version, and the `SDKROOT`, `DEVELOPER_DIR`,
`TOOLCHAINS`, and `MACOSX_DEPLOYMENT_TARGET` environment values.

SwiftPM commands run asynchronously through Swift Subprocess. Build output goes
directly to stderr. A successful run restores signal delivery and replaces the
swift-sh process with the compiled script through `execv`, preserving
arguments, standard streams, working directory, and the script's exit status.

## Package and Open

`PackageCommand` creates a temporary package beside the script, adds its
requirements through SwiftPM, and publishes the completed directory. Copying is
the default. Move mode protects the original until the destination succeeds and
restores it on a failure.

`OpenCommand` generates the cached package and computes an `EditorLaunch`:
`$EDITOR` with the generated source, run from the package directory, or
`open -a Xcode` with the package directory on macOS. The cached source remains
generated output; the original script is the durable source of truth.

Command contracts belong to the [command reference](../Reference/Commands.md)
and dependency syntax to the
[dependency comment reference](../Reference/DependencyComments.md).
