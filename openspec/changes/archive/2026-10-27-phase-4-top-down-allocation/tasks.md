# Tasks

## 1. Plan and SPI

- [x] 1.1 Settle the five phase-4 owner decisions and write the phase-4 plan into `UPGRADE.md`; verify the plan matches the kickoff handoff.
- [x] 1.2 Introduce the allocation SPI (`_embed(into:at:)` with `ViewRect`) and keep measurement as a pure query; verify the engine and Latte suites compile and pass.

## 2. Allocation kernel

- [x] 2.1 Port the walker's allocation rules into the per-conformer containers (`VStack`, `HStack`, `FrameView`, structural views); verify the parity corpus stays green.
- [x] 2.2 Add the `Text` compression floor so measurement and painting agree at narrow mixed-content widths; verify `EmbedKernelTests` and `AllocationRulesTests`.
- [x] 2.3 Add the `Fill`-under-`HStack` allocation rules and the two corpus cases; verify `SpacerAndFillTests` and the corpus expectations.

## 3. Renderer and wrappers

- [x] 3.1 Flip the renderer to one root allocation after the sizing query and delete the proposal-carrying render SPI; verify `RendererEnginePathTests`, `RendererTests`, and the full suite.
- [x] 3.2 Land the tree-based modifier wrappers (`.padded`, `.margined`, `.bordered`, `.beside`, `.above`); verify `ModifierWrapperTests` and `SimplePathContractTests`.
- [x] 3.3 Retire the eager `_resolveToViewOutput()` path and the eager `ViewOutput` modifiers; verify the corpus collapsed to a single `expectedRows` spec and all suites pass.
- [x] 3.4 Unify `Spacer()`/`Spacer(fraction:)` as flexible and remove `FlexibleSpacer`; verify the corpus spacer case and `FlexibilityTests`.

## 4. Type erasure and hard-box containment

- [x] 4.1 Make `AnyView` forward all four SPI methods, including `_flexibility()`; verify `AnyViewTests.erasedFlexibleSpacerStillAbsorbsLeftover`.
- [x] 4.2 Make the allocated rect the painting bound (kernel clip, container rect clamping, wide-character drop) and remove `.clipped()`/`ClipView`; verify `HardBoxTests` and `CellBufferClipTests`.

## 5. Documentation and verification

- [x] 5.1 Rewrite the layout-engine sections of `ARCHITECTURE.md` and the AGENTS/CLAUDE pitfalls for the allocation contract; verify the docs match the current SPI names.
- [x] 5.2 Run `swift build && swift test` and confirm the suite is green; record the known SpicesTests `viewAs` deprecation warnings as the only allowed warning exception.
