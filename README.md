# `swift sh` ![badge-platforms] ![badge-languages]

`swift-sh` runs single-file Swift scripts with SwiftPM dependencies declared
next to their `import` statements.

```sh
cat <<'EOF' > script
#!/usr/bin/swift sh
import Collections  // apple/swift-collections ~> 1.2
print(Deque(["Hi", "from", "swift-sh"]))
EOF
chmod u+x script
./script
```

`swift-sh` reads dependency comments after imports, creates a cached SwiftPM
package, builds the script executable, and runs it.

## Requirements

- Swift 6.3 or newer
- macOS 14 or newer, or a supported GitHub-hosted Ubuntu runner

## Installation

```sh
brew install swift-sh
```

You can also build from source:

```sh
swift build
```

The primary executable is `swift-sh`. When it is on `PATH`, Swift can invoke it
as `swift sh`.

## Quick Start

Create a script:

```swift
#!/usr/bin/swift sh

import Foundation
import Collections  // apple/swift-collections ~> 1.2

var queue = Deque(["build", "run", "ship"])
while let item = queue.popFirst() {
  print(item)
}
```

Run it directly through `swift-sh`:

```sh
swift sh foo.swift
```

Or make it executable:

```sh
chmod u+x foo.swift
mv foo.swift foo
./foo
```

## Common Commands

```text
swift sh <script> [arguments]
swift sh - [arguments]
swift sh -- [arguments]
swift sh package <script> [--force] [--move]
swift sh open <script> [--xcode]
swift sh cache clean [<script>]
```

- `swift sh <script>` builds and runs a script.
- `swift sh package <script>` creates a SwiftPM package from a script.
- `swift sh open <script>` opens the generated package source in `$EDITOR`.
- `swift sh open --xcode <script>` opens the generated SwiftPM package in Xcode.
- `swift sh cache clean` removes all cached script builds, or one script's cache
  when a script path is provided.

For complete command behavior, see
[Command Reference](Documentation/Reference/Commands.md).

## Dependency Comments

Dependencies are declared in comments after import lines:

```swift
import ExampleKit      // @example
import ArgumentParser  // apple/swift-argument-parser ~> 1.8
import Markdown        // swiftlang/swift-markdown == 0.8.0
import Collections     // apple/swift-collections
import BumbleButt      // https://example.com/bb.git ~> 9
import Foo             // ./my/project
```

Transitive dependencies do not need comment specifications. For the full
grammar, supported repository forms, local path rules, and version constraints,
see [Import Specifications](Documentation/Reference/ImportSpecifications.md).

## Script Arguments

Arguments after the script path are passed through to the compiled script:

```sh
swift sh deploy.swift --env production --dry-run
```

For complex script CLIs, import Swift Argument Parser in the script itself:

```swift
import ArgumentParser  // apple/swift-argument-parser ~> 1.8

@main
struct Deploy: ParsableCommand {
  @Option var env: String
  @Flag var dryRun: Bool
}
```

## Editing And Packaging

Use `swift sh open ./myScript` to generate the cached package and open the
generated source in `$EDITOR`. Use `swift sh open --xcode ./myScript` on macOS
to open the generated SwiftPM package in Xcode. This opens the SwiftPM package
directly; it does not generate an `.xcodeproj`.

Use `swift sh package foo.swift` when a script should become a normal SwiftPM
package. The command creates `./Foo` and copies the script into the SwiftPM
source tree. Add `--move` to move the original script into the generated
package.

## Use In CI

Scripts can be streamed through stdin:

```sh
brew install swift-sh
swift sh <(curl https://example.com/yourscript) arg1 arg2
```

## Examples

- [Terminal Rainbow](Examples/terminal-rainbow)
- [Swift Markdown example](Examples/markdown)
- [PostgreSQL Check](https://gist.github.com/joscdk/c4b89add26509c6dfabf84974e62543d)

## Documentation

- [Documentation index](Documentation/README.md)
- [Runtime architecture](Documentation/Architecture/RuntimeArchitecture.md)
- [Reference material](Documentation/Reference/README.md)
- [Contributing](CONTRIBUTING.md)

## Sponsorship

If your company depends on `swift-sh`, please consider sponsoring the project.

## Troubleshooting

If you see an error like:

```text
error: unable to invoke subcommand: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-sh
```

install `swift-sh` and ensure it is on `PATH`:

```sh
brew install swift-sh
```

[badge-platforms]: https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey.svg
[badge-languages]: https://img.shields.io/badge/swift-6.3-orange.svg
