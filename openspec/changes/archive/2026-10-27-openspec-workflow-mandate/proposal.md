# Proposal

## Why

Chai has an OpenSpec workflow, but the contributor guidance still allows
feature and maintenance work to bypass it. That produces drift between the
behavior contract, tests, and documentation, and makes it hard to tell which
changes are intentional. The project has now decided that **every repository
change** must go through the official OpenSpec lifecycle.

## What Changes

- Require an OpenSpec change for **every** code, test, documentation, CI,
  release, and tooling change. No direct-to-`main` changes.
- Standardize on **archive inside the pull request**: run `/opsx-archive`
  before merge so the PR carries the implementation, the spec merge, and the
  archived change folder together. Do not archive in a follow-up push to
  `main`.
- Document the lifecycle: propose → review → apply → archive, all inside one
  pull request that is then merged.
- Define when a change may set `skip_specs: true` (pure refactor, tooling, or
  documentation with no observable behavior delta) and when a delta spec is
  mandatory (any observable behavior change).
- Update `AGENTS.md`, `CLAUDE.md`, `README.md`, and `openspec/README.md` to
  state the mandate and point to the workflow.
- Update `docs/ROADMAP.md` so every initiative is explicitly labelled as an
  OpenSpec change.
- Make CI enforce the workflow with `openspec validate --all --strict` (the CI
  workflow itself lands in `phase-0-release-hygiene`).
- **Non-goals:** no product behavior, API, test-expectation, or dependency
  changes. No new capability spec is introduced because this is a process and
  documentation change; `.openspec.yaml` sets `skip_specs: true`.

## Capabilities

### New Capabilities

- None. This change alters contributor process and documentation only. It has
  no observable product behavior delta, so it deliberately opts out of specs
  with `skip_specs: true` rather than inventing a requirement.

### Modified Capabilities

- None.

## Impact

- `AGENTS.md`, `CLAUDE.md`, `README.md`, `openspec/README.md`,
  `docs/ROADMAP.md`.
- CI enforcement is provided by the `phase-0-release-hygiene` workflow.
- No source, public API, runtime, or dependency impact.
