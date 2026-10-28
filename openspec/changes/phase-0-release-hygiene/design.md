# Design

## Context

Chai is pre-alpha (`swift-tools-version: 6.1`, macOS 14+, Linux via `Glibc`)
with no `LICENSE`, no in-repo CI, no changelog, and known
`Progress.viewAs(_:)` deprecations in `SpicesTests` (12 call sites; the
documentation says 13). The production targets build warning-free; the test
target does not. The repository is hosted on GitHub. OpenSpec is at 1.15 and
is becoming mandatory through `openspec-workflow-mandate`.

## Goals / Non-Goals

**Goals:**

- MIT license at the root and in the README.
- CI that proves build, tests, OpenSpec validation, and zero warnings on macOS
  and Linux.
- A clean warning baseline with no allowlist.
- A changelog and version policy that make `0.1.0` a deliberate release.

**Non-Goals:**

- No runtime, renderer, layout, input, or component behavior changes.
- No new dependencies.
- No performance benchmarking in CI (that is a later roadmap item).
- No release automation beyond documented tagging steps.

## Decisions

### 1. MIT license, copyright "Chai contributors"

The user selected MIT. Use the standard MIT text with
`Copyright (c) 2026 Chai contributors` until a legal name is supplied. The
holder string is easy to change before a 1.0 release and does not affect the
grant. Alternatives considered: Apache-2.0 (declined by the user) and no
license (rejected as an adoption blocker).

### 2. GitHub Actions with a macOS and Linux matrix

Use GitHub Actions because the repository is on GitHub. Start with
`macos-14` for the documented minimum platform and `ubuntu-latest` with the
official Swift 6.1 container (or `swift-actions/setup-swift` pinned to 6.1).
Pin third-party actions to commit SHAs. Cache SwiftPM builds and checkouts.
Triggers: `push` to `main`, `pull_request`, and `workflow_dispatch`, with
`concurrency` cancellation for superseded runs.

Alternatives considered: a single Linux job (rejected: macOS-specific POSIX
and terminal paths must be exercised), macOS-only (rejected: the README
claims Linux support), and a self-hosted runner (rejected: no infrastructure
requirement for Phase 0).

### 3. Warning gate: fail on any `warning:` in the build log

After the deprecation cleanup, run `swift build --build-tests` and fail if the
captured output contains `warning:`. A grep gate is more predictable than
`-warnings-as-errors` across SDK and toolchain versions, and it covers test
targets, which is where the current debt lives. The step must print the
offending lines before failing. Alternatives considered:
`-Xswiftc -warnings-as-errors` (rejected for now: SDK warnings can fail the
build for reasons outside the project) and allowing a known-warning list
(rejected: the list is being removed).

### 4. OpenSpec validation is a required CI step

Run `npx -y @fission-ai/openspec@1.15.0 validate --all --strict`. Pinning the
version keeps validation reproducible. The step runs once per workflow, not
once per platform, unless the second job needs it for parity.

### 5. Deprecation cleanup is a test-only refactor

Replace `Progress.viewAs(_:)` with `viewAsStyledText(_:)` in
`Tests/SpicesTests/SpicesTests.swift`. There are 12 call sites today even
though the contributor docs and `openspec/config.yaml` say 13; verify the
actual count and correct the documentation as part of the change. Preserve the
expected output and the number of assertions. Do not change the production
`Progress` API in this change; if the replacement reveals a behavior
difference, stop and open a separate behavior change.

### 6. Changelog and version policy

Use Keep a Changelog headings. Record `0.1.0` as the first tagged release with
the pre-alpha status, supported platforms, and a link to `docs/ROADMAP.md`.
Document SemVer: `0.x` may break, `1.0.0` follows the API audit. The tag is
created only after the change is merged and the CI matrix is green.

### 7. Branch protection is a documented manual step

CI checks are only mandatory if branch protection requires them. Document the
required checks in `AGENTS.md`/`openspec/README.md`; configuring GitHub branch
protection is an administrative step outside the repository. Alternatives
considered: a bot that enforces protection (rejected: unnecessary for Phase 0).

## Risks / Trade-offs

- **macOS runner minutes** → cache SwiftPM and keep the matrix to one macOS and
  one Linux job. Add more OS versions only when needed.
- **Swift 6.1 availability on runners** → use the official Linux container and
  pin `setup-swift` on macOS; record the exact toolchain in CI logs.
- **Warning-grep false positives** → after the cleanup the baseline is zero;
  fail closed and fix or document any toolchain-introduced warning rather than
  adding an allowlist.
- **Copyright holder ambiguity** → "Chai contributors" is a placeholder;
  revisit before 1.0.
- **Flaky timer/input tests under CI** → if a test is timing-sensitive, make it
  deterministic or mark it explicitly; do not add retries that hide failures.
- **OpenSpec npx network dependency** → pin the version and cache npm; the
  validation job can run after checkout without Swift toolchain setup.

## Migration Plan

1. Add `LICENSE`, `CHANGELOG.md`, and README/AGENTS updates.
2. Replace the deprecated test call sites and verify `swift test` with zero
   warnings locally.
3. Add the CI workflow and open a pull request to exercise both jobs.
4. Archive this change inside the PR once the matrix is green, then merge.
5. After merge, create and push `v0.1.0`.
6. Rollback: revert the change; there is no runtime behavior to restore.

## Open Questions

- Exact copyright holder string before 1.0.
- Whether to add a second macOS runner version after the first green matrix.
