# Tasks

## 1. Terminal input decoding

- [x] 1.1 Add the `ESC [[` branch to `InputParser.parseOne` that maps the fourth byte `A`–`E` to F1–F5, falling through to the generic CSI path when the fourth byte is absent or out of range; remove the unreachable `ESC [[` entries from `csiTable`. Verify with new `InputParserTests` cases for `ESC [[ A`–`ESC [[ E` and for a bare `ESC [[` followed by text.
- [x] 1.2 Make `parsePrintable` return zero consumed bytes when it stops on an incomplete UTF-8 sequence with more data possible and no complete character was collected. Verify with a test that feeds a truncated lead byte across two reads and asserts it is retained, then completed.
- [x] 1.3 Simplify the `canHaveMoreData` argument in `InputParser.parse` to pass the flag directly instead of recomputing an always-true bound. Verify the full `InputParserTests` suite still passes.
- [x] 1.4 Remove the dead `case 0x1B` from the named-control switch. Verify the existing Escape and Alt tests still pass.
- [x] 1.5 Extend `Tests/ChaiTests/InputParserTests.swift` to cover the remaining `terminal-input` scenarios: SS3 arrows and F1–F4, Home/End variants, modified arrows including Alt, Shift+Tab, unrecognized-CSI skipping without text leakage, multi-byte and wide-character runs, invalid-byte skipping, and lone/Alt escape. Verify with `swift test --filter InputParserTests`.

## 2. ANSI content sanitization

- [x] 2.1 Add one internal escape-sequence scanner that removes CSI, OSC, SS3/SS2, and two-byte escape sequences and reuses the skipping logic already used for visible-width measurement. Verify with unit tests covering each sequence family, a malformed trailing escape byte, and ordinary text containing `[` and `]` that must be untouched.
- [x] 2.2 Apply the scanner in `StyledText.init(_:style:)`, `append(_:style:)`, `StringInterpolation.appendLiteral`, and the string overloads of `appendInterpolation`; delete the assertion and rewrite the DocC on `ViewOutput.init(_ content: String)` to describe sanitization. Verify with `swift test --filter StyledTextTests` and `--filter ViewOutputLayoutTests`.
- [x] 2.3 Add tests asserting that ANSI-encoded content is painted as plain text, contributes no display width, that an OSC sequence and its parameters never appear in painted output, and that sanitization applies to interpolated literals as well as direct strings. Verify with `swift test --filter ViewOutputLayoutTests` and `--filter StyledTextTests`.

## 3. Extended underline in the structured path

- [x] 3.1 Add `underlineStyle` (default `.none`) and `underlineColor` (default `nil`) to `Cell` and `TextAttributes`, and map both from `Style.textAttributes` using the documented resolution rule. Verify with `swift test --filter CellTests` and `--filter StyleTests`.
- [x] 3.2 Move SGR parameter construction for a cell into one helper and call it from both `Cell.render()` and `Renderer.cellSGR(_:)`, so underline variants and underline color are emitted once and consistently. Verify with `swift test --filter CellTests` and `--filter RendererTests`.
- [x] 3.3 Update `StyledView.merge` to adopt the outer underline style and color only when the cell has no underline of its own, and include the new fields in the applicability check. Verify with `swift test --filter StyledViewTests`.
- [x] 3.4 Add tests for double, curly, dotted, and dashed underlines, underline color with and without a style, inner-underline precedence under a nesting modifier, and inline-versus-modifier parity; update `UnderlineStyleTests` for the structured path. Verify with `swift test --filter UnderlineStyleTests` and `--filter StyledViewParityTests`.
- [x] 3.5 Update the DocC on `Cell`, `TextAttributes`, `Style.textAttributes`, and `StyledView` to state that underline style and color are carried structurally. Verify the documentation builds as part of `swift build`.

## 4. Color capability detection

- [x] 4.1 Match `COLORTERM` case-insensitively in `ColorProfile.detect` and update its DocC. Verify with `ColorTests` cases for `truecolor`, `TrueColor`, `24bit`, and `24BIT`, plus the existing no-color and 256-color cases.

## 5. Input reader lifecycle

- [x] 5.1 Make the reader loop the sole owner of closing the cancellation descriptors and finishing the continuation; have `stop()` only signal cancellation, with lock-protected lifecycle state so a stop before the loop runs cleans up directly and a stop after it exits does not write to a recycled descriptor. Update the type's concurrency annotation and document the mutable-state invariant. Verify with `swift test --filter ProgramTests`.
- [x] 5.2 Add a lifecycle test that starts a reader over a test descriptor, stops it, and asserts the stream finishes exactly once and no descriptor is closed twice. Verify with `swift test --filter ProgramTests`.

## 6. Library hygiene

- [x] 6.1 Replace the force-unwraps in `TabExpansion.swift` and `Color.swift` with guarded or total expressions. Verify with `swift test --filter TabExpansionTests` and `--filter ColorTests`.
- [x] 6.2 Delete the unused ANSI constants for cursor-up-one, scroll margins, line insertion, mouse tracking, bracketed paste, and focus reporting, and remove the redundant `Renderer.write(_ view: ViewOutput)` overload. Verify `swift build` succeeds with no unresolved references and `swift test --filter RendererStructuralTests` passes.
- [x] 6.3 Document on `Program.run()` that a program is single-use because its message stream is finished at shutdown, and state the supported way to run again. Verify with `swift test --filter ProgramTests` and by reading the rendered DocC comment.

## 7. Documentation drift and integration

- [x] 7.1 Correct `ARCHITECTURE.md`: replace the stale test and suite counts with the current numbers and remove the obsolete warning note about `Progress.viewAs(_:)`. Verify the numbers match `swift test` output and no stale warning claim remains.
- [x] 7.2 Correct `AGENTS.md` so it describes `Progress.viewAs(_:)` as removed rather than deprecated, consistent with the current `Progress` API and `ARCHITECTURE.md`. Verify with a repository search for the removed symbol.
- [x] 7.3 Run the full gate: `swift build && swift test` with zero warnings in production and test targets, and `npx -y @fission-ai/openspec@1.15.0 validate --all --strict` with all capabilities passing.

## Workflow follow-up

- Read the finished implementation against the three delta specs and confirm every scenario has a corresponding test.
- Archive the change on the branch after review and validation pass, keeping the implementation, spec merge, and archive move in one pull request.
