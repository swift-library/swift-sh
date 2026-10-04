# Commands

## Synopsis

```text
swift sh <script> [arguments]
swift sh - [arguments]
swift sh -- [arguments]
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

When stdin is not a TTY, `swift sh` can read script source from stdin. Use `-`
or `--` to force stdin mode when needed.

## Package A Script

`swift sh package <script> [--force] [--move]` creates a SwiftPM package from a
script. The command creates a capitalized package directory next to the script,
initializes it with SwiftPM, copies the script into the generated executable
source path, and uses SwiftPM commands to add dependencies.

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

`swift sh cache clean` deletes the full `swift-sh` cache.

Passing a script path deletes only that script's cache:

```sh
swift sh cache clean ./foo.swift
```

## Help

Use `swift sh --help` or `swift sh -h` to print command usage.

## Version and Exit Status

`swift sh --version` prints the tool version and exits successfully, including
when stdin is redirected. After a script path, `-`, or `--`, the same argument
is forwarded to the script.

Help and version exit with 0, command or build failures with 2, and invalid
command usage with 3. A successfully built script takes over the process and
retains its own exit code and signal termination. Build logs use stderr,
leaving stdout for the script.
