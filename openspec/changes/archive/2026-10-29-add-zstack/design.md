# Design

## Context

`VStack` and `HStack` are allocation containers: they query children, decide
child rects, and embed each child through `CellBuffer.embed`, which installs the
hard-box clip. `FrameView` is the allocator for a single child. There is no
container that gives several children the same box. See `proposal.md` for
motivation and `ARCHITECTURE.md` → "The Layout Engine" for the measure/embed
contract this design must preserve.

## Goals / Non-Goals

**Goals:**

- Add an overlay container whose children share one box and paint in
  declaration order.
- Reuse the existing query/allocation/hard-box machinery without adding a new
  render path, identity, or diffing.
- Keep the public API consistent with the existing one-dimensional stacks.

**Non-Goals:**

- Flexible-space distribution inside the overlay (no main axis exists).
- z-index, explicit ordering, opacity, blending, or background fill.
- Any change to the renderer root policy, Spices, or the example app.

## Decisions

### Combined `Alignment` value

Add a `Sendable, Equatable` struct with a `HorizontalAlignment` and a
`VerticalAlignment`, defaulting to `.center`/`.middle`. Presets are
`.topLeft`, `.top`, `.topRight`, `.left`, `.center`, `.right`, `.bottomLeft`,
`.bottom`, and `.bottomRight`; custom positions use
`Alignment(horizontal:vertical:)`. This mirrors SwiftUI's `ZStack(alignment:)`
and avoids a four-parameter initializer. The alternative — separate
`horizontalAlignment`/`verticalAlignment` parameters — was rejected because
every call site that wants a corner would repeat two labels, and the pair is a
single reusable concept.

### Overlay allocation, not main-axis distribution

`ZStack` queries every child with the assigned width **and** height (the stacks
pass `nil` on their main axis). It occupies the maximum reported width and
maximum reported height, and never distributes leftover space. Consequently a
flexible `Spacer()` remains inert, exactly as it is outside a main-axis stack,
and a `Fill` child grows the stack on any axis with a non-`nil` context (width
only in inline mode). Passing the width context is what makes a wrapping `Text`
child report the same line count it will paint; passing the height context lets
a `Fill` or a nested flexible stack respond to the assigned box.

### One shape function for measurement and embedding

Like the stacks, `ZStack` resolves measurement and allocation through a single
`allocation(assignedWidth:assignedHeight:)` helper: query children, compute the
occupied size, and return each child's allocated size. `_measure` returns the
occupied size (a pure report); `_embed` recomputes the shape from the assigned
rect, then positions each child.

Embedding re-queries children under the rect the stack was allocated. A child
whose report depends on the query context — a nested `VStack` with a flexible
`Spacer`, for example — can therefore report a different size at embed time
than it did during measurement. The stack uses that embed-time report clamped
to its allocation, so the difference cannot paint outside the rect. This is the
same recomputation the main-axis stacks perform, and a nested-flex case pins it.

Placement uses the occupied box clamped to the assigned rect
(`min(occupied, rect)`), so content that exceeds the allocation is clipped
rather than used to push siblings outside. Each child's rect is its report
under the assigned rect clamped to the assigned rect, offset by
`Int(Double(shortage) * fraction)` on each axis independently — the same
truncated fractional rule as the stacks. The rect is intersected with the
stack's rect and embedded with `buffer.embed`, so the hard-box invariant is
inherited unchanged.

### Declaration order is z-order

Children are embedded in order. A later child's painted cells replace earlier
cells entirely, including their background; a child that paints nothing
(`Empty`, `Fill`, a flexible `Spacer`) leaves earlier content visible. This is
the terminal equivalent of SwiftUI's ZStack ordering and needs no extra state.
Because a later leaf replaces earlier cells, a background painted before the
content is punched through by the content's glyph and space cells. Style the
stack itself (`.bg(...)`) or paint the background last.

### File placement and public surface

- `Sources/Chai/Layout/Alignment.swift`: the combined `Alignment` value beside
  the existing axis alignments.
- `Sources/Chai/Layout/Stacks.swift`: `ZStack` beside `VStack`/`HStack`, since
  it is the third allocation container and shares the stack terminology.
- `Sources/Chai/Chai.swift`, `README.md`, and `ARCHITECTURE.md`: document the
  container and its overlay semantics.

`ZStack<Content: View>` is `Sendable` through its generic constraint, and
`Alignment` is a value type. No concurrency boundary or actor isolation
changes.

## Risks / Trade-offs

- **Later cells replace earlier cells, including background** → Documented and
  pinned in both paint orders. Callers style the stack itself or paint the
  background last; no blending or opacity is introduced.
- **A shrink-wrapped root ZStack centers within its own content box** → The
  same shrink-wrap rule as the stacks' cross axis. Callers who want a
  full-terminal overlay use a `Fill` child or `.frame(...)`; tests pin the
  shrink-wrap behavior so it cannot drift silently.
- **Query and embed can differ for context-sensitive children** → A nested
  flexible stack can report a larger size at embed time than at measure time.
  The stack clamps the resulting rect to its allocation, and a nested-flex case
  pins the behavior so it is intentional rather than accidental.
- **Query and embed can differ for `Fill` in inline mode** → `Fill` reports the
  assigned height only when the rect exists; the embed box is the measured
  height, so it fills the stack rather than changing its measured size. This is
  the existing `Fill` contract and has explicit coverage.
- **Preset naming is new surface** → Keep the preset set small and derived from
  the existing `.left`/`.right` and `.top`/`.middle`/`.bottom` names; custom
  fractions cover everything else.

## Migration Plan

Additive only. No deprecations, no behavior change to existing containers, and
no dependency or platform change. Rollback is deleting the new types and tests.
