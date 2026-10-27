# Design

## Context

Chai uses OpenSpec 1.15 with the `spec-driven` schema. Before this change it
has one capability (`layout-engine`), no active changes, and contributor
guidance that presents OpenSpec as the preferred workflow rather than a
requirement. There is no CI yet; the companion `phase-0-release-hygiene`
change introduces one.

## Goals / Non-Goals

**Goals:**

- One rule: every repository change is represented by an OpenSpec change.
- A clear, narrow definition of when `skip_specs: true` is legitimate.
- One canonical policy document, with the other contributor docs pointing to
  it.
- CI enforcement through `openspec validate --all --strict`.

**Non-Goals:**

- No product behavior, API, test-expectation, or dependency changes.
- No new capability spec for process documentation.
- No custom OpenSpec schema or CLI fork.

## Decisions

### 1. Keep the default `spec-driven` schema

Use the configured schema for every change. A custom schema would add
maintenance cost without changing the lifecycle. Alternatives considered:
a custom "chore" schema (rejected: `skip_specs` already covers non-behavior
work) and per-change schemas (rejected: inconsistent artifacts).

### 2. Every change gets a change folder; behavior changes require specs

All work — features, fixes, refactors, tests, docs, CI, release chores — starts
with `openspec new change <name>`. A change that alters observable behavior
must include a delta spec. A pure refactor, tooling, or documentation change
sets `skip_specs: true` and still produces a proposal, design (when useful),
and tasks. This preserves an audit trail without inventing requirements for
work that has no behavior delta.

### 3. `AGENTS.md` is canonical; `CLAUDE.md` points to it

`AGENTS.md` owns the workflow rules because the agent guide is the contributor
contract. `CLAUDE.md` mirrors the mandate in one short section and links to
`AGENTS.md` instead of duplicating the full policy. `README.md` and
`openspec/README.md` link to the same rules. Alternatives considered:
maintaining two full copies (rejected: drift) and moving policy into
`openspec/config.yaml` (rejected: config guides artifacts, not contributor
behavior).

### 4. Enforce with CI, not local hooks

`phase-0-release-hygiene` adds `openspec validate --all --strict` to the CI
workflow. Git hooks are not portable across contributor setups and are easy to
bypass; CI plus required checks is the enforceable boundary. The CI step is
the only enforcement mechanism introduced here.

### 5. No direct-to-`main` edits; archive inside the PR

Every change lands through a change folder and a pull request. After the tasks
are complete and validation passes, run `/opsx-archive` on the feature branch
so the same PR carries the implementation, the delta-spec merge, and the
archived change folder. Do not archive in a follow-up push to `main`, and do
not push directly to `main` at all.

Rationale: the repository wants the spec merge reviewed together with the
code, and it does not want to depend on a post-merge direct push. The branch is
the review unit; the archive move is part of that unit. Alternatives
considered: archive after merge (OpenSpec's team default; rejected here
because it requires either a direct push or a second PR and leaves `main`
temporarily without the spec merge) and an emergency bypass (rejected:
exceptions become the norm).

### 6. Pin the OpenSpec CLI in CI

Use an explicit version (currently 1.15.0) through `npx` in CI so validation
does not change silently. Contributors may use a newer local CLI, but CI is
the compatibility gate.

## Risks / Trade-offs

- **Process overhead for tiny changes** → the `skip_specs` path keeps the
  artifact set small; the proposal and tasks are usually a few paragraphs.
- **Contributors may set `skip_specs` when behavior changed** → add an
  explicit checklist line to `AGENTS.md` and require reviewers to confirm the
  behavior delta. CI cannot infer semantics.
- **`AGENTS.md` and `CLAUDE.md` drift** → make `CLAUDE.md` a short pointer, not
  a second source of truth.
- **OpenSpec CLI version skew** → pin the CI version and document the local
  install command.
- **Archive-inside-PR makes the diff noisier and archives work before merge**
  → the archive move is part of the reviewed branch; if the PR is rejected,
  move the change folder back or continue on the branch. `main` only receives
  the archive after review and merge.

## Migration Plan

1. Archive this change inside its pull request, then merge it.
2. Land the CI validation step through `phase-0-release-hygiene`.
3. Apply the rule to all subsequent changes; existing archived changes are
   untouched.
4. Rollback is a documentation revert; there is no runtime impact.

## Open Questions

- None. The OpenSpec version pin is resolved in the companion CI design.
