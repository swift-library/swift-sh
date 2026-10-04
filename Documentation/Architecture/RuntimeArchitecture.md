# Runtime Architecture

## Scope

`swift-sh` is the sole public SwiftPM product. Its implementation lives in the
internal `Sh` executable target; `ShTests` validates syntax and command behavior
using Swift Testing.

## Dependencies and Ownership

Swift Argument Parser owns command declarations and help. SwiftParser and
SwiftSyntax own Swift syntax recognition. Swift System supplies paths and file
descriptors, Foundation supplies file operations and input handles, and Swift
Subprocess owns asynchronous SwiftPM execution. SemVer owns strict version
parsing; script-specific abbreviations and revision fallback belong to Sh.
SHA-256 uses CryptoKit on macOS and Swift Crypto on Linux.

The package uses Swift 6.3 and supports macOS 15 and Linux. Its macOS source
build needs the SDK from Xcode 26 or newer for Swift Subprocess. Dependency
ranges and `Package.resolved` constrain the supported compiler line.

## Input and Analysis

`ScriptSource` reads a file, stdin, or named pipe once into a UTF-8 snapshot.
It owns the resolved source identity and directory for relative dependencies.
A leading shebang becomes a comment on the same line; script contents and
subsequent diagnostic line numbers are preserved.

`ScriptAnalysis` walks real syntax nodes to collect imports, their trailing
line comments, and `@main` attributes. Comments and string literals cannot
create declarations. Both branches of conditional compilation are collected;
condition evaluation remains the compiler's responsibility.

`ImportSpecification` adapts import metadata to SwiftPM package and product
requirements. The imported module name must identify an exported library
product. It normalizes supported repository forms, resolves local paths, and
escapes strings through the manifest renderer.

## Generated Package and Cache

`Script` renders the full manifest and a generated source copy. Top-level code
uses `main.swift`; attributed entry points use `Root.swift`. Switching entry
forms removes the previous generated entry. Generated writes preserve the
user-owned source file, including when an old cache entry is a symbolic link.
The generated package uses the current host macOS deployment version.

`BuildCache` uses SHA-256 identities. File inputs key by their resolved path;
stream inputs key by source contents, input kind, and dependency directory.
`XDG_CACHE_HOME` overrides the parent cache directory. Otherwise macOS uses
`$HOME/Library/Developer/swift-sh.cache` and Linux uses `$HOME/.cache/swift-sh`.

A successful build records hashes of the generated source and manifest, the
selected toolchain identity, and sorted local dependency file metadata. A
changed input or missing binary triggers a build. Local dependency metadata
includes file names, sizes, and modification times and excludes hidden paths.
An unversioned remote dependency follows a broad version range when SwiftPM
resolves it; a hot cached script retains its resolved build until invalidated
or cleaned.

Process locks serialize generation and builds for one cache key. Shared locks
allow separate scripts to build concurrently and coordinate with whole-cache
cleaning. Lock files live outside removable cache directories; descriptors
close on final exec. Old cache formats are rebuilt under the new identities.

## Toolchain and Execution

`SwiftToolchain` resolves Swift from `PATH`, resolves the macOS system shim with
`xcrun`, and verifies Swift 6.3 or newer. A cached version check is keyed by the
compiler path and file metadata, host system version, and SDK/toolchain-related
environment values.

SwiftPM commands run asynchronously through Swift Subprocess. Build output goes
directly to stderr. Captured commands consume stdout and stderr together and
retain their termination status. A successful run replaces the swift-sh process
with the compiled script using POSIX exec, preserving arguments, signals,
standard streams, working directory, and the script's exit status.

## Package and Open

`ScriptPackaging` creates a temporary package beside the script, adds its
requirements through SwiftPM, and publishes the completed directory. Copying is
the default. Move mode protects the original until the destination succeeds and
restores it on a failure.

`ScriptOpening` generates the cached package before invoking `$EDITOR` or
opening the package in Xcode. The cached source remains generated output; the
original script is the durable source of truth.

Command contracts belong to the [command reference](../Reference/Commands.md)
and dependency syntax to the [import reference](../Reference/ImportSpecifications.md).
