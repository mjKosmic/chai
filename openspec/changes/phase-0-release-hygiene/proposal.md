# Proposal

## Why

Chai is pre-alpha and architecturally strong, but it is not yet legally or
operationally easy to adopt: there is no `LICENSE` file, there is no in-repo
CI to prove macOS and Linux builds, and the test target carries known
`Progress.viewAs(_:)` deprecation warnings. These are cheap, high-signal
blockers compared with runtime or layout work.

## What Changes

- Add an MIT `LICENSE` at the repository root and a license statement in
  `README.md`.
- Add a GitHub Actions CI workflow that runs on macOS and Linux:
  - `swift build --build-tests`
  - `swift test`
  - `openspec validate --all --strict`
  - a zero-warning gate for production targets and test targets
- Migrate the known `Progress.viewAs(_:)` call sites in `SpicesTests` to
  `viewAsStyledText(_:)` (12 call sites; the docs said 13) so the warning gate
  can be fully enforced.
- Add `CHANGELOG.md` and document the version policy (`0.x` until the 1.0 API
  audit, then SemVer).
- Prepare the `0.1.0` release notes and tagging instructions; the tag is
  created only after the change is merged and CI is green.
- Update `AGENTS.md` to remove the known-warning exception and point at the CI
  gate.
- **Non-goals:** no runtime, renderer, layout, input, or component behavior
  changes; no new dependencies; no layout-corpus changes.
- **BREAKING:** none.

## Capabilities

### New Capabilities

- None. This change is release tooling, documentation, and a test-only
  refactor; it has no observable product behavior delta and sets
  `skip_specs: true` rather than inventing a requirement.

### Modified Capabilities

- None.

## Impact

- New files: `LICENSE`, `.github/workflows/ci.yml`, `CHANGELOG.md`.
- Modified files: `README.md`, `AGENTS.md`,
  `Tests/SpicesTests/SpicesTests.swift`, `docs/ROADMAP.md`.
- No source behavior, public API, or dependency changes.
- Depends on the `openspec-workflow-mandate` change for the documented
  workflow that the CI step enforces.
