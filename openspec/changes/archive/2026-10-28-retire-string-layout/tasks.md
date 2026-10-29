# Tasks

## 1. Baseline and clamp relocation

- [x] 1.1 Record the baseline before editing: run `swift build --build-tests`, `swift test`, and `npx -y @fission-ai/openspec@1.15.0 validate --all --strict`; capture the test/suite counts and `grep -c "expectedRows:" Tests/LatteTests/LayoutParity/ParityCorpus.swift`. Verification: all three commands pass and the counts are recorded in the PR description.
- [x] 1.2 Create `Sources/Chai/Core/StyledText+Clamping.swift` with the surviving raster-clamp internals (`Line`, `splitLines`, `truncated(toWidth:)`, `clampWidth`, `clampHeight`) moved from `Sources/Latte/Extensions/StyledText+Layout.swift`, using Chai's internal `displayWidth`. Verification: `swift build` succeeds.
- [x] 1.3 Create `Sources/Chai/Core/ViewOutput+Clamping.swift` from `Sources/Latte/Extensions/ViewOutput+Layout.swift` and delete the Latte file; rewrite the doc comment to describe raster truncation without "simple path" or String-helper wording. Verification: `swift build` succeeds and `grep -rn "ViewOutput+Layout" Sources` is empty.
- [x] 1.4 Move `Tests/LatteTests/ViewOutputLayoutTests.swift` to `Tests/ChaiTests/` and update its import. Verification: `swift test --filter ViewOutputLayout` passes.
- [x] 1.5 Split `Tests/LatteTests/DisplayWidthTests.swift`: move the `displayWidth`, `visibleWidth`, and `truncateToVisibleWidth` cases to `Tests/ChaiTests/` with `@testable import Chai`; delete the `height` and `size` cases with the helpers. Verification: `swift test --filter DisplayWidth` passes against the Chai implementation.

## 2. Preserve features the string renderer currently owns

- [x] 2.1 Move `Sources/Spices/Internal/StyleBridge.swift` to `Sources/Latte/Style/Style+TextAttributes.swift`, keeping `Style.textAttributes`, `Style.styledText(_:)`, `Color.cellColor`, and `ANSIColor.cellColor` public. Verification: `swift build` succeeds, `swift test --filter Spices` passes, and `grep -rn "StyleBridge" Sources` is empty.
- [x] 2.2 Extend `BorderView` and the `.bordered` modifier with per-side `Style?` parameters (`borderStyle`, `topStyle`, `bottomStyle`, `leftStyle`, `rightStyle`) and paint border glyph cells with the resolved `TextAttributes`; corners inherit their horizontal edge's style, and content inside the border is unstyled. Verification: new `BorderView` styling tests pass and `swift test --filter Border` passes.
- [x] 2.3 Port the style-application cases from `Tests/LatteTests/BorderTests.swift` to `BorderView` (uniform style, per-side override, corner inheritance, content untouched, styled glyph width unchanged); keep the glyph-set and equatable cases; drop the `border()` rendering and profile-specific cases. Verification: `swift test --filter Border` passes and `grep -c "border(" Tests/LatteTests/BorderTests.swift` is 0.
- [x] 2.4 Move `String.tabsExpanded()` from `Extensions/String+Layout.swift` into `Utilities/TabExpansion.swift`, keeping `expandTabs` unchanged; move its cases from `StringExtensionTests` into `TabExpansionTests`. Verification: `swift test --filter TabExpansion` passes and `grep -rn "tabsExpanded" Sources/Latte` resolves to `TabExpansion.swift`.

## 3. Delete the string layout layer

- [x] 3.1 Delete `Sources/Latte/Borders/BorderRenderer.swift`. Verification: `swift build` succeeds and `grep -rn "func border(" Sources` is empty.
- [x] 3.2 Delete `Composition/Join.swift`, `Composition/Compositor.swift`, `Static/ListRenderer.swift`, `Static/TreeRenderer.swift`, `Utilities/StringLines.swift`, `Extensions/String+Layout.swift`, `Layout/Size.swift`, `Layout/Wrap.swift`, `Layout/Inline.swift`, `Layout/Margin.swift`, and `Layout/Padding.swift`. Verification: `swift build` succeeds.
- [x] 3.3 Remove `align()` and its now-unused line-splitting call from `Layout/Alignment.swift`, keeping `HorizontalAlignment` and `VerticalAlignment` with their fraction and literal helpers. Verification: `swift build` succeeds and `grep -n "func align" Sources/Latte` is empty.
- [x] 3.4 Delete `Sources/Latte/Extensions/StyledText+Layout.swift` after 1.2 has the surviving helpers. Verification: `swift build` succeeds and `grep -rn "StyledText+Layout" Sources` is empty.
- [x] 3.5 Reduce `Sources/Latte/Measurement/DisplayWidth.swift` to the internal `displayWidth(of:)` overloads used by `BorderView`; delete `visibleWidth`, `height`, `size`, `truncateToVisibleWidth`, and the ANSI-skipping helpers only they use. Verification: `swift build` succeeds, `grep -rn "visibleWidth\|truncateToVisibleWidth\|func height(\|func size(" Sources/Latte` is empty, and `grep -rn "displayWidth" Sources/Latte` reports only `BorderView.swift`, `Utilities/TabExpansion.swift`, and `Measurement/DisplayWidth.swift`.
- [x] 3.6 Delete the string-API test suites: `AlignmentTests`, `CompositorTests`, `InlineTests`, `JoinTests`, `ListRendererTests`, `PaddingTests`, `SizeTests`, `StringExtensionTests`, `TreeRendererTests`, and `WrapTests`. Verification: `swift test` compiles and runs without those symbols.
- [x] 3.7 Update `Sources/Latte/Latte.swift` module documentation to cover styling, the declarative containers/modifiers, border glyphs, and tab expansion only; remove the string-layout API tables and examples and note that raster clamping lives on `ViewOutput`. Verification: `swift build` succeeds and `grep -n "joinHorizontal\|joinVertical\|align(\|func pad(\|visibleWidth\|truncateToVisibleWidth\|ListRenderer\|TreeRenderer\|Compositor" Sources/Latte/Latte.swift` is empty.
- [x] 3.8 Update `README.md` (module table) and `ARCHITECTURE.md` (module table and the "Latte — Layout & Styling Library" section) to remove the string-layout modules and describe Latte as styling plus the tree containers. Verification: `grep -rn "joinHorizontal\|ListRenderer\|TreeRenderer\|Compositor\|String+Layout" README.md ARCHITECTURE.md` is empty.
- [x] 3.9 Update `AGENTS.md` (repository layout and the engine-seam paragraph), `docs/ROADMAP.md` (R14 and any Latte claim that names string helpers), and `openspec/config.yaml` context to describe the surviving Latte surface. Verification: `grep -rn "joinHorizontal\|ListRenderer\|TreeRenderer\|Compositor\|String+Layout" AGENTS.md docs/ROADMAP.md openspec/config.yaml` is empty.
- [x] 3.10 Add a **BREAKING** entry with the migration table to `CHANGELOG.md` under Unreleased, including the `.bordered` style parameters and the retained `expandTabs`/`tabsExpanded`. Verification: the entry names the removed API and points at the view-tree replacements; `git diff --check` passes.

## 4. Spices cleanup

- [x] 4.1 Delete `Progress.viewAs(_:)` and its private `renderMultiStopGradient` and `renderGradient` String helpers, keeping the StyledText versions. Verification: `grep -rn "viewAs(" Sources Tests` is empty and `swift test --filter Progress` passes.
- [x] 4.2 Update `Sources/Spices/Spices.swift` documentation to remove the "layout primitives (`border`, `pad`, `align`, etc.)" claim and describe styling plus the view-tree modifiers. Verification: `grep -n "border\|pad\|align" Sources/Spices/Spices.swift` reports no layout-primitive claim.

## 5. Contract and coverage

- [x] 5.1 Rewrite `Tests/LatteTests/SimplePathContractTests.swift` to keep only the tree-path model and assertions; remove `StringPathApp`, its tests, and the two-shapes comments. Verification: `swift test --filter SimplePath` passes.
- [x] 5.2 Add a test pinning a single-leaf body as a complete frame, covering the `view-api` "body with a single leaf" scenario. Verification: the new test passes and its name matches the scenario.
- [x] 5.3 Map every `view-api` scenario to an owning test, adding tests for any gap; record the mapping in the change notes. Note that the ANSI-content scenario is enforced by the `ViewOutput` initializer assertion and is not unit-testable without crashing. Verification: the mapping covers all scenarios and `swift test` passes.

## 6. Integration verification

- [x] 6.1 Run `swift build --build-tests 2>&1 | tee /tmp/chai-retire-build.log` and verify `grep -c "warning:" /tmp/chai-retire-build.log` is 0.
- [x] 6.2 Run `swift test` and verify all tests pass; compare the count with 1.1 and record the delta from deleted suites and added tests.
- [x] 6.3 Verify `grep -c "expectedRows:" Tests/LatteTests/LayoutParity/ParityCorpus.swift` equals the baseline from 1.1, proving no layout expectation moved.
- [x] 6.4 Run `npx -y @fission-ai/openspec@1.15.0 validate --all --strict` and `git diff --check`; verify both pass.
- [x] 6.5 Run `swift build --product GroceryList` and verify the example still builds after Latte's surface shrinks.
- [x] 6.6 Confirm the removed public symbols are absent from `Sources/Latte` with a single grep for `joinHorizontal`, `joinVertical`, `Compositor`, `ListRenderer`, `TreeRenderer`, `enforceWidth`, `clampWidth(`, and `visibleWidth`.

## Workflow follow-up

- Push the branch and open a pull request; verify the `macos`, `linux`, and `openspec` jobs pass.
- Archive this change inside the pull request; verify `openspec/specs/view-api/spec.md` is created and the change moves under `openspec/changes/archive/`.
- After merge, propose `fold-latte-into-chai` to move the surviving Latte code into Chai and remove the product.
