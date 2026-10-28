# Tasks

## 1. License and release metadata

- [x] 1.1 Add an MIT `LICENSE` at the repository root using `Copyright (c) 2026 Chai contributors`. Verify the file exists and contains the standard MIT grant and warranty disclaimer.
- [x] 1.2 Add a License section to `README.md` linking `LICENSE`. Verify with `grep -n "MIT" README.md`.
- [x] 1.3 Add `CHANGELOG.md` in Keep a Changelog format with a `0.1.0` entry covering the pre-alpha status, supported platforms, and a link to `docs/ROADMAP.md`. Verify the file parses as Markdown and the entry matches the release policy in `design.md`.

## 2. Warning cleanup

- [x] 2.1 Replace every `Progress.viewAs(_:)` call in `Tests/SpicesTests/SpicesTests.swift` with `viewAsStyledText(_:)`, preserving assertions. Verify the actual call-site count (currently 12; the docs say 13), `grep -c "viewAs("` is 0, and `grep -c "viewAsStyledText("` matches the replaced count.
- [x] 2.2 Correct the stale warning count in `AGENTS.md`, `openspec/config.yaml`, and `docs/ROADMAP.md`; state that the test target is warning-free after this change. Verify no remaining "13" deprecation claims contradict the actual count.
- [x] 2.3 Run `swift package clean && swift build --build-tests 2>&1 | tee /tmp/chai-build.log` and verify `grep -c "warning:" /tmp/chai-build.log` is 0. Run `swift test` and verify all tests pass with the same count as before (1,278 tests / 110 suites).
- [ ] 2.4 Fix the Linux-only unused-result warning in `Sources/Chai/Core/Logger.swift` by explicitly discarding `createFile`'s result, and verify the Linux CI job is warning-free. This warning was surfaced by the first CI run; it is a warning-only change with no behavior delta.

## 3. CI workflow

- [x] 3.1 Add `.github/workflows/ci.yml` with a `macos` job on `macos-14` and a `linux` job using Swift 6.1, both running `swift build --build-tests` and `swift test`. Verify the YAML parses (for example with `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml")'`).
- [x] 3.2 Add the zero-warning step: capture the build log and fail if it contains `warning:`, printing the offending lines first. Verify the step fails when a warning is injected into a scratch copy and passes on the clean tree.
- [x] 3.3 Add an `openspec` job pinned to `npx -y @fission-ai/openspec@1.15.0 validate --all --strict`. Verify the command passes locally from the repository root.
- [ ] 3.4 Add triggers (`push` to `main`, `pull_request`, `workflow_dispatch`), concurrency cancellation, and SwiftPM caching. Verify by reading the workflow and, after pushing, with `gh workflow view`.
- [x] 3.5 Document the required CI checks and branch-protection step in `AGENTS.md` and `openspec/README.md`. Verify the documented job names match `macos`, `linux`, and `openspec` in `ci.yml`.

## 4. Release preparation

- [x] 4.1 Document the `0.1.0` tagging procedure (after merge and a green matrix): `git tag -a v0.1.0 -m "Chai 0.1.0"` and `git push origin v0.1.0`. Verify the commands are in `CHANGELOG.md` or `docs/RELEASING.md`.
- [x] 4.2 Update `docs/ROADMAP.md` Phase 0 to link this change and mark the release as gated on the green CI matrix, not as already done. Verify the links and wording.
- [x] 4.3 Run `npx -y @fission-ai/openspec@1.15.0 validate --all --strict` and `git diff --check`; verify both pass.

## 5. Integration verification

- [x] 5.1 Run `swift build --build-tests` and `swift test` on macOS; verify zero warnings and 1,278 tests passing.
- [x] 5.2 Verify the CI workflow's local equivalents pass on a clean checkout: `swift package clean`, build/test, warning grep, and OpenSpec validation.
- [x] 5.3 Confirm the Linux job definition uses the documented Swift 6.1 toolchain and that its commands match the local verification commands.

## Workflow follow-up

- Push the branch and open a pull request; verify the macOS, Linux, and OpenSpec jobs pass.
- Archive this change inside its pull request before merge.
- After merge, create and push the annotated `v0.1.0` tag. Do not push directly to `main`.
