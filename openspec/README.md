# OpenSpec in Chai

This directory holds Chai's **behavior specifications** and change history.
OpenSpec separates current behavior from proposed changes:

```
openspec/
├── config.yaml                  # project context + artifact rules for agents
├── specs/                       # source of truth: current behavior
│   └── layout-engine/spec.md
└── changes/
    ├── <change-name>/           # active proposals
    │   ├── .openspec.yaml
    │   ├── proposal.md          # why + what
    │   ├── specs/<capability>/spec.md  # delta specs (ADDED/MODIFIED/REMOVED)
    │   ├── design.md            # how (when needed)
    │   └── tasks.md             # implementation checklist
    └── archive/
        └── 2026-10-27-phase-4-top-down-allocation/
```

## Capability map

Specs are organized by durable system behavior, not by implementation layer.
The first capability is:

| Capability | Covers |
|------------|--------|
| `layout-engine` | Measurement reports, parent allocation, hard-box clipping, stack distribution, `Text` wrapping, renderer root/buffer policy |

Add a capability only when a change introduces a cohesive, long-lived behavior
that can own related requirements. Do not create a capability per file or per
task; extend an existing spec with a delta when the behavior belongs to it.

## Workflow

1. **Explore / propose** — use `/opsx-propose` (OpenCode) or `/opsx:propose`
   (Claude Code), or `openspec new change <name>` and write the artifacts.
2. **Review** — validate with
   `npx -y @fission-ai/openspec@latest validate <change> --strict`.
3. **Apply** — work through `tasks.md`, checking boxes as work lands.
4. **Archive** — `npx -y @fission-ai/openspec@latest archive <change> -y`
   merges delta specs into `specs/` and dates the change folder.

Skills and commands are generated in `.opencode/` and `.claude/` by
`openspec init` / `openspec update`. Regenerate them after upgrading the CLI:

```bash
npx -y @fission-ai/openspec@latest update
```

## Relationship to the other docs

- `ARCHITECTURE.md` — design of record (how the system is built).
- `docs/history/VIEW-LAYER-MIGRATION-LOG.md` — chronological migration log and phase plans.
- `openspec/specs/` — behavior contract (what the system must do now).
- `openspec/changes/archive/` — why past changes were made, with their design
  and completed tasks.

When a change alters externally visible behavior, update the spec delta first
and the design/architecture docs where the design itself changes.
