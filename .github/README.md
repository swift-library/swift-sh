# .github

This directory indexes GitHub-facing collaboration and automation files for
`swift-sh`.

## Contents

- `workflows/ci.yml`: SwiftPM build and test matrix.
- `workflows/commit-message.yml`: pull request commit subject policy.

## Placement

- Keep GitHub Actions workflows under `workflows/`.
- Keep GitHub-specific collaboration configuration in `.github/`.
- Keep repository documentation in `Documentation/`.
- Keep contributor guidance in root governance files such as
  `CONTRIBUTING.md`.

## Release Automation

GitHub release and package distribution automation should be added only after
the target repository, package registry, and Homebrew tap are owned by this
project. Do not publish to upstream-owned channels from this repository.
