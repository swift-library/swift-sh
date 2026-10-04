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
- For detailed command or import syntax changes, update
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
- Keep detailed command/import syntax in `Documentation/Reference/*` rather
  than expanding this guide.

## Operating Notes

- Keep Agent Guide and Index separate.
- Keep current architecture truth out of reference material.
- Keep GitHub collaboration configuration out of `Documentation/`.
