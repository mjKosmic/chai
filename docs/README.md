# Documentation

This directory holds long-form project documentation that is not a behavior
spec and not a change proposal.

| Document | Purpose |
|----------|---------|
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | Design of record: runtime, renderer, input, concurrency, and the layout engine |
| [`history/VIEW-LAYER-MIGRATION-LOG.md`](history/VIEW-LAYER-MIGRATION-LOG.md) | Chronological migration log for the declarative view tree and layout engine (phases 1–5, SPI rename) |
| [`history/PHASE-4-TOP-DOWN-ALLOCATION-SPIKE.md`](history/PHASE-4-TOP-DOWN-ALLOCATION-SPIKE.md) | Historical phase-4 investigation report and evidence for the allocation engine |
| [`../openspec/README.md`](../openspec/README.md) | OpenSpec structure, capability map, and workflow |

## Where things live

- **Behavior contract:** `openspec/specs/<capability>/spec.md` — current,
  testable requirements and scenarios.
- **Proposed work:** `openspec/changes/<change>/` — proposal, delta specs,
  design, and tasks.
- **Completed work:** `openspec/changes/archive/` — dated changes, including
  the preserved phase-4 kickoff handoff.
- **Design and history:** this directory and `ARCHITECTURE.md`.
- **Contributor rules:** `../AGENTS.md` / `../CLAUDE.md`.

Historical documents preserve the paths they referenced when written; their
current locations are listed above. The phase-4 kickoff handoff, for example,
lives in
[`../openspec/changes/archive/2026-10-27-phase-4-top-down-allocation/design.md`](../openspec/changes/archive/2026-10-27-phase-4-top-down-allocation/design.md).
