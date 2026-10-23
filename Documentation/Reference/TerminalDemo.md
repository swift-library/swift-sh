# Terminal demonstration

The README shows an actual run of [the version script](../../Examples/version.swift).
Its import comment pins swift-semver, and the script prints the next minor
version for the argument it receives.

[`.github/assets/terminal/script.yml`](../../.github/assets/terminal/script.yml)
defines the example source and the displayed commands. A hidden setup step
builds the script with its pinned dependency and captures SwiftPM diagnostics
in the sandbox's `build.log`. The displayed invocations reuse that build.
A hidden cleanup step removes the script's build cache; the recorder removes
its temporary home after each run.

Build swift-sh, then use the `github-readme-design` toolchain's terminal recorder:

```sh
swift build -c release
node <toolchain>/src/cli.ts terminal record \
  --script .github/assets/terminal/script.yml \
  --executable .build/release/swift-sh \
  --out .github/assets/terminal/recording.json
node <toolchain>/src/cli.ts terminal check --recording-only \
  --assets .github/assets/terminal --executable .build/release/swift-sh
```

The toolchain's [local regeneration instructions](https://github.com/showxu/skills/blob/master/skills/github-readme-design/references/renderers.md#local-regeneration)
describe its Node version, installation, and rendering commands. Use the
organization's accepted DESIGN and fonts to render `terminal-light.svg` and
`terminal-dark.svg` beside the recording. The README selects the matching
appearance from those assets.

The `demo` declaration in [`.github/swift-package.json`](../../.github/swift-package.json)
selects the shared validation job. It rebuilds the release executable and
compares a fresh recording with the committed `recording.json`.

The two script invocations demonstrate argument forwarding and package-backed
execution. Light and dark variants are generated from the same recording.
