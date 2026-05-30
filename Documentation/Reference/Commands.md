# Commands

## Synopsis

```text
swift sh <script> [arguments]
swift sh - [arguments]
swift sh -- [arguments]
swift sh package <script> [--force] [--move]
swift sh open <script> [--xcode]
swift sh cache clean [<script>]
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
source in `$EDITOR`.

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
