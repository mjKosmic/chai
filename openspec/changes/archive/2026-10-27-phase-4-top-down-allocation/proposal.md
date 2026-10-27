# Proposal

## Why

Phase 4 replaced Chai's proposal-driven layout negotiation with top-down
allocation — *children report; parents decide*. The phase-4 kickoff handoff is
now historical, but the behavior it established is still the layout engine's
current contract. The repository needs a durable behavior specification rather
than only a chronological migration log.

This change archives the handoff as the design record and seeds the first
OpenSpec capability, `layout-engine`.

## What Changes

- Move the phase-4 kickoff handoff from `HANDOFF.md` into this archived change
  as `design.md`, preserving its content.
- Add `openspec/specs/layout-engine/spec.md` as the behavior contract for
  measurement, allocation, hard-box containment, stacking, `Text` wrapping, and
  root buffer policy.
- Add `openspec/README.md` and project configuration so future work follows the
  OpenSpec workflow.
- **No source behavior changes.** This is a retroactive documentation/spec
  archive for work that already landed.

## Capabilities

### New Capabilities

- `layout-engine`: Top-down allocation of a view tree into terminal cells:
  measurement reports, parent-allocated rects, hard-box clipping, stack
  distribution, `Text` wrapping, and renderer root allocation.

### Modified Capabilities

- None.

## Impact

- **Docs/specs:** `HANDOFF.md` moves to
  `openspec/changes/archive/2026-10-27-phase-4-top-down-allocation/design.md`;
  the root README and agent guides link to the new OpenSpec layout.
- **Code:** none.
- **Tests:** the existing parity corpus and allocation suites remain the
  verification evidence; no expectation changes.
- **Public API:** none.
