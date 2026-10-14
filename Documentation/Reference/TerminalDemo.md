# Terminal demonstration

The README shows an actual run of [the version script](../../Examples/version.swift).
Its import comment pins swift-semver, and the script prints the next minor
version for the argument it receives. The recording retains commands, standard
output, and exit codes. SwiftPM build diagnostics use standard error, so they
do not appear in the demonstration.

Build swift-sh, then record the commands:

```sh
swift build -c release --force-resolved-versions
python3 Scripts/record-demo.py
```

The recorder uses `.build/demo-session` and `.build/demo-cache`, and writes
the committed `Documentation/Assets/Demo-record.json`. Its local provenance
record includes compiler and executable identities; raw standard error stays
under `.build/demo-session`.

The full commit in `.github/presentation.json` pins the shared terminal renderer
and the organization's DESIGN.md. `Scripts/check-demo` fetches those two public
files under `.build/presentation/shared` and verifies both SVG variants. To
regenerate them, run that fetched renderer with the same arguments, omitting
`--check`. The organization owns design tokens; this package does not copy
DESIGN.md.

The image does not claim a timing result or a cold-cache performance comparison.
Its two script invocations demonstrate argument forwarding and package-backed
execution. Light and dark variants are generated from the same recording.
