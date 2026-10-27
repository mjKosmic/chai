# Documentation

This directory holds long-form project documentation that is not a behavior
spec and not a change proposal.

| Document | Purpose |
|----------|---------|
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | Design of record: runtime, renderer, input, concurrency, and the layout engine |
| [`ROADMAP.md`](ROADMAP.md) | Prioritized, sequenced plan for high-impact improvements |
| [`history/VIEW-LAYER-MIGRATION-LOG.md`](history/VIEW-LAYER-MIGRATION-LOG.md) | Chronological migration log for the declarative view tree and layout engine (phases 1–5, SPI rename) |
| [`history/PHASE-4-TOP-DOWN-ALLOCATION-SPIKE.md`](history/PHASE-4-TOP-DOWN-ALLOCATION-SPIKE.md) | Historical phase-4 investigation report and evidence for the allocation engine |
| [`../openspec/README.md`](../openspec/README.md) | OpenSpec structure, capability map, and workflow |
| [`../AGENTS.md`](../AGENTS.md) | Canonical contributor policy, including the mandatory OpenSpec workflow |

Behavior specs live in `../openspec/specs/` and are the behavior contract.
This page, `AGENTS.md`, and `ROADMAP.md` are process/design documents, not
behavior contracts.

## Where things live

- **Behavior contract:** `openspec/specs/<capability>/spec.md` — current,
  testable requirements and scenarios.
- **Proposed work:** `openspec/changes/<change>/` — proposal, delta specs,
  design, and tasks.
- **Completed work:** `openspec/changes/archive/` — dated changes, including
  the preserved phase-4 kickoff handoff.
- **Design and history:** this directory and `ARCHITECTURE.md`.
- **Contributor rules:** `../AGENTS.md` (canonical) and `../CLAUDE.md` (short
  mirror).
- **Process:** every change requires an OpenSpec change and is archived inside
  its pull request before merge; never push directly to `main`. See
  `../AGENTS.md` and `../openspec/README.md`.

Historical documents preserve the paths they referenced when written; their
current locations are listed above. The phase-4 kickoff handoff, for example,
lives in
[`../openspec/changes/archive/2026-10-27-phase-4-top-down-allocation/design.md`](../openspec/changes/archive/2026-10-27-phase-4-top-down-allocation/design.md).
