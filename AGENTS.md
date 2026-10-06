# swift-sh Agent Guide

Read `README.md` first for repository purpose, user-facing commands, and entry
points.

## First-Principles Work

- Name the behavior, root cause, invariant, owner, data flow, and validation
  before changing reusable files.
- Change the owning layer, not the nearest convenient file.
- Keep changes traceable to the request, source evidence, or owning invariant.
- Validate with package-local checks when behavior changes.

## Task Route

- For documentation placement or wording changes, read
  `Documentation/README.md` before editing.
- For current architecture descriptions, read
  `Documentation/Architecture/README.md` and the relevant architecture files.
- For detailed command or dependency comment syntax changes, update
  `Documentation/Reference/*` and keep the root `README.md` concise.
- For GitHub-facing collaboration files, use `.github/` and root governance
  files.
- For SwiftPM package changes, keep `Package.swift`, `Package.resolved`, and
  the CI workflow aligned.
- Stop and clarify before mixing route instructions into `README` files or
  index text into `AGENTS.md`.

## Authority

- `AGENTS.md` is the agent guide for repository work.
- `README`-class files index scope, placement, and user entry points.
- `Documentation/Architecture/*` is current architecture truth.
- `Documentation/Reference/*` is supporting reference material.
- `.github/*` is GitHub-facing governance and automation.

## Boundary Guardrails

- Do not promote machine-local paths, one-run state, fixture-only values, or
  temporary execution state into reusable docs, scripts, templates, or
  automation.
- If a value changes by input or environment, pass it in, configure it, derive
  it, or link to the owning artifact.
- Keep detailed command and dependency comment syntax in
  `Documentation/Reference/*` rather than expanding this guide.

## Code Review Rules

### Compatibility and versioning

- Flag a change to public API or observable behavior, including a raised
  minimum platform or Swift version, without the change record and version
  bump `Documentation/Architecture/VersioningAndRelease.md` requires. Safe
  path: record the change under the next version with that bump.

### Claims

- Flag README, DocC, or release-note statements that the code and tests do
  not support: capabilities that do not exist, existing behavior described as
  new, or platforms CI does not build. Safe path: describe what the code
  shows.

### Public documentation

- Flag a new public symbol without a documentation comment, and public prose
  that compares the package with other projects or describes internal
  process. Safe path: document the symbol, and describe only this package's
  own behavior.

### Tests

- Flag a behavior change without a test that would fail before the change.
  Safe path: add the test beside the existing suite for that behavior.


## Operating Notes

- Keep Agent Guide and Index separate.
- Keep current architecture truth out of reference material.
- Keep GitHub collaboration configuration out of `Documentation/`.
