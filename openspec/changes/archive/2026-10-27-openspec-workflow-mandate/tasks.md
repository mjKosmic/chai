# Tasks

## 1. Policy documentation

- [x] 1.1 Update `AGENTS.md` with a "Mandatory OpenSpec workflow" section: every change starts with `openspec new change <name>`; observable behavior changes need a delta spec; pure refactor/tooling/docs changes set `skip_specs: true`; no direct-to-`main` edits; lifecycle is propose → review → apply → archive. Verify by reading the section and confirming it links to `openspec/README.md`.
- [x] 1.2 Update `CLAUDE.md` with a short mirror that points to `AGENTS.md` as the canonical policy instead of duplicating the full rules. Verify the pointer resolves and the text matches the mandate.
- [x] 1.3 Update `README.md` and `openspec/README.md` to state the mandate and link the workflow. Verify with `grep -n "OpenSpec" README.md openspec/README.md` that no contradictory "preferred/optional" language remains.

## 2. Roadmap and documentation index

- [x] 2.1 Add a process note to `docs/ROADMAP.md` stating that every initiative starts as an OpenSpec change and that Phase 0 chores use `skip_specs: true`. Verify the "How to execute" section states the rule.
- [x] 2.2 Update `docs/README.md` so the documentation index points contributors at the mandate and the roadmap. Verify the links resolve and the page distinguishes behavior specs from process docs.

## 3. CI enforcement

- [x] 3.1 Document the required branch-protection checks (CI, OpenSpec validation) in `AGENTS.md` and `openspec/README.md`. Verify the documented check names match the planned `ci.yml` job names and that the text notes the checks are enforced once `phase-0-release-hygiene` lands.
- [x] 3.2 Add a short "Enforcement" note to `openspec/README.md` stating that `openspec validate --all --strict` runs in CI and that reviewers must reject changes without an OpenSpec change. Verify the note links the CI workflow path.

## 4. Verification

- [x] 4.1 Run `npx -y @fission-ai/openspec@1.15.0 validate --all --strict` and verify it passes with this change active.
- [x] 4.2 Run `git diff --check` and verify no whitespace errors; review the changed docs for contradictory workflow statements.

## 5. Archive-inside-PR convention

- [x] 5.1 Update `AGENTS.md` to state that every change is archived inside its pull request before merge: run `/opsx-archive` on the branch after tasks and validation pass, never push directly to `main`, and let the PR carry the archive move. Verify by reading the mandate and required-checks sections for a consistent rule.
- [x] 5.2 Update `openspec/README.md` Workflow and Enforcement sections and the `docs/README.md` process note: archive before merge inside the same PR, no direct pushes to `main`, and branch protection requires a pull request plus the `macos`, `linux`, and `openspec` checks. Verify the workflow ordering and enforcement text agree.
- [x] 5.3 Update `docs/ROADMAP.md` "How to execute" so archive-inside-PR is the final step and direct-to-`main` pushes are prohibited. Verify the steps read propose → review → apply → archive → merge.
- [x] 5.4 Run `npx -y @fission-ai/openspec@1.15.0 validate --all --strict`, `git diff --check`, and `swift test`; verify all pass and no doc still describes a merge-first archive flow.

## Workflow follow-up

- After `phase-0-release-hygiene` lands, verify the CI workflow actually runs `openspec validate --all --strict` and that the required checks are active in branch protection.
- Archive this change inside its pull request before merge.
- Verify no active change is left behind and the roadmap still points to the process.
