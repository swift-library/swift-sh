# Commands

## Synopsis

```text
swift sh [--debug] <script> [arguments]
swift sh [--debug] - [arguments]
swift sh [--debug] -- [arguments]
swift sh run [--debug] <script> [arguments]
swift sh package <script> [--force] [--move]
swift sh open <script> [--xcode]
swift sh cache clean [<script>]
swift sh --version
```

## Run A Script

`swift sh <script> [arguments]` reads the script, extracts dependency comments
from imports, builds a cached SwiftPM package, and executes the generated
binary. Arguments after the script path are forwarded to the script without
being parsed by `swift-sh`.

`swift sh - [arguments]` and `swift sh -- [arguments]` read the script source
from stdin and forward every following argument to the script. Without any
arguments, `swift sh` reads the script from stdin when stdin is not a TTY and
reports invalid usage when it is. Any other first argument is a script path,
whether or not stdin is a TTY, and may name a file or a named pipe. A script
path that cannot be opened, such as a missing file, is a command failure;
swift-sh names the path and does not read stdin. A first argument that starts
with `-` and is not `-`, `--`, `--debug`, `--help`, `-h`, or `--version` is
invalid usage.

`run` is the default command. Name it explicitly to run a script whose path is
also a command name, such as `swift sh run package`.

### Build Configuration

Scripts build in release configuration. `--debug`, placed before the script
path, builds and runs a debug binary instead, which compiles faster and keeps
full debugger information. After the script path, `--debug` is a script
argument. Each configuration has its own binary and build record, so switching
does not rebuild the other. Scripts with `@testable` imports build their release
modules with testing enabled.

A cached binary is reused until the generated source or manifest, the contents
of a local dependency, the Swift toolchain, or the build arguments change, or
the binary is missing.

## Package A Script

`swift sh package <script> [--force] [--move]` creates a SwiftPM package from a
script. The command creates a capitalized package directory next to the script,
initializes it with SwiftPM, copies the script into the generated executable
source path, and uses SwiftPM commands to add dependencies. An import without a
version constraint gets its repository's newest release as the lower bound.

By default the script must have a supported `swift-sh` shebang and the original
script remains in place. Use `--force` to skip the shebang check. Use `--move`
to move the original script into the generated package.

## Open For Editing

`swift sh open <script>` writes the generated package and opens the generated
source in `$EDITOR`. The editor value identifies one executable. Edits in the
cached copy are temporary; the next generation uses the original script again.

`swift sh open --xcode <script>` is available on macOS. It writes the generated
package and opens the SwiftPM package in Xcode. It does not generate an
`.xcodeproj`.

## Cache

Builds live in `~/Library/Caches/swift-sh` on macOS and `~/.cache/swift-sh` on
Linux. When `XDG_CACHE_HOME` holds an absolute path, builds live in
`$XDG_CACHE_HOME/swift-sh` on either system; an empty or relative value is
ignored.

`swift sh cache clean` deletes the full `swift-sh` cache, including the release
selections of versionless imports. On macOS it also removes
`~/Library/Developer/swift-sh.cache` and its lock directory, which releases
before 0.2.0 used.

Passing a script path deletes only that script's cache:

```sh
swift sh cache clean ./foo.swift
```

`swift sh cache` without a subcommand is invalid usage.

## Help

Use `swift sh --help` or `swift sh -h` to print command usage, and
`swift sh help <command>` or `swift sh <command> --help` for one command.

## Path Compatibility

Spaces and Unicode are supported in script names, local dependencies, and cache
directories. SwiftPM's supported toolchains cannot reliably build paths with
literal double quotes, backslashes, or control characters. These characters
must be absent from the generated cache path, script basename, and local package
paths. swift-sh reports this limitation before generating the package. A source
file may live in a directory containing quotes when its generated build paths
remain compatible.

## Version and Exit Status

`swift sh --version` prints the tool version and exits successfully, including
when stdin is redirected. After a script path, `-`, or `--`, the same argument
is forwarded to the script. `--version` followed by other arguments is invalid
usage.

Help and version exit with 0, command or build failures with 2, and invalid
command usage with 3. A successfully built script takes over the process and
retains its own exit code and signal termination. Build logs use stderr,
leaving stdout for the script.
