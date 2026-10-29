# Design

## Context

See `proposal.md` for motivation. The relevant current state:

- `Terminal/InputParser.swift` decodes CSI and SS3 with string-keyed lookup
  tables. Its CSI scanner takes the first byte in `0x40…0x7E` as the final byte,
  so `ESC [[ A` is split into `ESC [[` (unknown) plus a literal `A`.
- `Renderer/StyledText.swift` is the single string-to-styled-text entry point,
  but `StringInterpolation` appends literals directly to `segments`, and
  `Core/ViewOutput.swift` relies on a `assert` that is absent in release builds.
- `Cell.Attributes` is a `UInt8` option set and therefore cannot represent
  underline variants or an underline color; `Style.textAttributes` collapses
  every non-`.none` underline to the same bit.
- `Cell.render()` and `Renderer.cellSGR(_:)` each build an SGR parameter list,
  so any new decoration must be added in both or they will diverge.
- `InputReader` runs a blocking `select(2)`/`read(2)` loop on a dedicated
  `Thread`; `stop()` and the loop both finish the continuation, and `stop()`
  closes the descriptors while the loop may still be selecting on them.

Layout, measurement, allocation, and the hard-box invariant are untouched by
this change. `ARCHITECTURE.md` remains the design of record for those.

## Goals / Non-Goals

**Goals:**

- Make every behavior in the delta specs true, including release builds.
- Keep the public API additive: no existing signature or public symbol is
  removed or renamed.
- Leave one owner for each resource and one source of truth for each rule
  (one ANSI scanner, one cell-SGR builder, one stream finisher).

**Non-Goals:**

- Automatic color downsampling in the structured cell path. The cell path
  emits `CellColor` values directly today; this change does not add profile
  awareness to it, so underline colors follow the same rule as foreground and
  background colors.
- Mouse, bracketed-paste, and focus decoding.
- Any coupling between `ColorProfile.detect` and the renderer's output path.

## Decisions

### Decode Linux-console function keys with a dedicated branch

Recognize the three-byte introducer `ESC [[` in `parseOne` before the generic
CSI path and read the fourth byte as the key selector, mapping `A`–`E` to
F1–F5. Require all four bytes; otherwise fall through to the generic CSI path so
a bare `ESC [[` is still consumed as an unknown sequence.

- **Alternative considered:** teach the CSI scanner that `[` is an intermediate
  byte. Rejected: `[` is also a valid CSI final byte, so the scanner would
  change how every `ESC [` sequence terminates.
- The unreachable entries are removed from `csiTable` and live in a dedicated
  table keyed by the four-byte sequence.

### Fix the retained-bytes bug in the printable path

`parsePrintable` currently returns `(1, nil)` whenever no complete character was
collected, even when it stopped on an incomplete sequence and more data may
follow; that consumes the lead byte and loses a character split across reads.
The parser must return `(0, nil)` in that case so `parse` retains the bytes.
When no more data can follow, the truncated bytes are consumed and dropped as
today. This is required for the "Incomplete input is held" requirement and is
covered by a new test.

### Strip ANSI at the `StyledText` string boundary

Add one internal scanner that removes CSI, OSC, SS3/SS2, and two-byte escape
sequences, reusing the sequence-skipping logic already used by
`DisplayWidth.visibleWidth` rather than duplicating it. Apply it wherever a
`String` becomes content: `StyledText.init(_:style:)`, `append(_:style:)`,
`StringInterpolation.appendLiteral`, and the string overloads of
`appendInterpolation`. `ViewOutput.init(_ content: String)` delegates to
`StyledText`, so it inherits the behavior and its assertion is deleted.

- **Alternative considered:** strip at paint time, in `CellBuffer`. Rejected:
  `plainText` and width calculations would still see escape bytes, and callers
  could observe two different values for the same content.
- **Alternative considered:** keep the assertion and weaken the spec. Rejected
  by the scope decision: release builds must be safe, not merely documented as
  unsafe.
- A malformed or trailing escape byte is dropped; the scanner never invents
  visible text.

### Carry underline style and color as cell fields, not option-set bits

Add `underlineStyle` (default `.none`) and `underlineColor` (default `nil`) to
`Cell` and `TextAttributes`. Keep the existing `.underline` bit as the
"single underline" spelling for hand-built attribute sets, and define one
resolution rule used everywhere:

```
effective = underlineStyle != .none ? underlineStyle : (attributes.contains(.underline) ? .single : .none)
```

`Style.textAttributes` always sets `underlineStyle` and never the bit, so
`Style` has a single encoding. SGR emission moves into one `Cell` helper used
by both `Cell.render()` and `Renderer.cellSGR(_:)`; underline color is emitted
only when the effective style is not `.none`.

`StyledView.merge` adopts the outer underline style and color only when the
cell has neither (no style and no bit), preserving the inner-wins rule.

- **Alternative considered:** replace the `.underline` bit with the new field.
  Rejected: it removes a public symbol for no behavioral gain.
- **Alternative considered:** encode variants in the option set. Rejected:
  `UInt8` has two bits free and there are five styles plus a color.

Public impact is additive: `Cell.init` and `TextAttributes.init` gain
defaulted parameters, and both types gain two stored properties. `Cell` and
`TextAttributes` remain `Sendable` and `Equatable`; equality now distinguishes
underline variants, which is the intended behavior for buffer diffing.

### Match `COLORTERM` case-insensitively

Compare the lowercased value against `truecolor` and `24bit`. No other
detection rule changes.

### Give the input reader a single finisher

`readLoop` owns closing the cancellation descriptors and finishing the
continuation. `stop()` only signals: it writes the cancel byte and records that
a stop was requested. A small lock-protected `started`/`stopped` state lets
`stop()` clean up directly when the reader was never started, and prevents a
write to a recycled descriptor when the loop already exited. This requires
`InputReader` to become `@unchecked Sendable` with a documented invariant that
all mutable lifecycle state is lock-protected; the FDs and continuation remain
immutable `let`s.

### Document the single-run contract

`Program.run()` is documented as consuming the program: the message stream is
finished during shutdown, so a second call returns without starting a loop.
Creating a fresh channel per `run()` was considered and rejected because `send`
before `run` is documented to buffer into that channel; changing that is a
separate API decision.

## Risks / Trade-offs

- **Sanitization drops data an application may have intended to emit.** →
  The spec and DocC state the rule; `Style.render` remains the supported way to
  produce ANSI for out-of-band output.
- **The shared escape scanner could over-consume ordinary text containing
  `[` or `]`.** → Scanners only engage after an escape byte and only skip
  complete sequences; a lone escape byte is dropped, not treated as a prefix.
- **New `Cell` fields change buffer equality and therefore repaint decisions.**
  → Intended: cells differing only in underline variant must repaint. No
  layout or width impact, since underline decoration paints inside existing
  cells.
- **`InputReader` lifecycle state introduces a lock.** → The lock guards two
  booleans and is never held across I/O; the reader thread remains the only
  blocking caller.
- **Removing unused ANSI constants changes an internal type only.** → `ANSI`
  is internal, so no client is affected.
- **The F-key branch narrows generic CSI handling for `ESC [[`.** → Falling
  through when the fourth byte is not `A`–`E` keeps unknown-sequence behavior
  unchanged.
