import Testing
@testable import Spices
import Chai

@Suite("Style")
struct StyleTests {
    @Test func emptyStylePassesThrough() {
        let style = Style()
        #expect(style.render("hello") == "hello")
    }

    @Test func boldWrapsInANSI() {
        let style = Style().bold()
        let result = style.render("test")
        #expect(result.contains("\u{1B}["))
        #expect(result.contains("1"))
        #expect(result.hasSuffix("\u{1B}[0m"))
    }

    @Test func foregroundColor() {
        let style = Style().foreground(.ansi(.red))
        let result = style.render("red")
        #expect(result.contains("31"))
    }

    @Test func backgroundColor() {
        let style = Style().background(.ansi(.blue))
        let result = style.render("blue")
        #expect(result.contains("44"))
    }

    @Test func trueColorForeground() {
        let style = Style().foreground(.trueColor(r: 255, g: 128, b: 0))
        let result = style.render("orange")
        #expect(result.contains("38;2;255;128;0"))
    }

    @Test func extendedColor() {
        let style = Style().foreground(.extended(208))
        let result = style.render("ext")
        #expect(result.contains("38;5;208"))
    }

    @Test func hexColor() {
        let color = Color.hex("#FF6B35")
        #expect(color != nil)
        if case let .trueColor(r, g, b) = color {
            #expect(r == 255)
            #expect(g == 107)
            #expect(b == 53)
        }
    }

    @Test func composedStyle() {
        let style = Style()
            .foreground(.ansi(.green))
            .bold()
            .underline()
        let result = style.render("styled")
        #expect(result.contains("32"))   // green fg
        #expect(result.contains("1"))    // bold
        #expect(result.contains("4"))    // underline
    }
}

@Suite("ColorProfile")
struct ColorProfileTests {
    @Test func detectNoColorEnv() {
        let profile = ColorProfile.detect(
            environment: ["NO_COLOR": "1"],
            isTerminal: true
        )
        #expect(profile == .noColor)
    }

    @Test func detectNotATTY() {
        let profile = ColorProfile.detect(
            environment: [:],
            isTerminal: false
        )
        #expect(profile == .noColor)
    }

    @Test func detectTrueColorFromColorterm() {
        let profile = ColorProfile.detect(
            environment: ["COLORTERM": "truecolor"],
            isTerminal: true
        )
        #expect(profile == .trueColor)
    }

    @Test func detectTrueColorFrom24bit() {
        let profile = ColorProfile.detect(
            environment: ["COLORTERM": "24bit"],
            isTerminal: true
        )
        #expect(profile == .trueColor)
    }

    @Test func detectTrueColorFromTermProgram() {
        let profile = ColorProfile.detect(
            environment: ["TERM_PROGRAM": "iTerm.app"],
            isTerminal: true
        )
        #expect(profile == .trueColor)
    }

    @Test func detectAnsi256FromTerm() {
        let profile = ColorProfile.detect(
            environment: ["TERM": "xterm-256color"],
            isTerminal: true
        )
        #expect(profile == .ansi256)
    }

    @Test func detectAnsiFromXterm() {
        let profile = ColorProfile.detect(
            environment: ["TERM": "xterm"],
            isTerminal: true
        )
        #expect(profile == .ansi)
    }

    @Test func defaultIsAnsi() {
        let profile = ColorProfile.detect(
            environment: [:],
            isTerminal: true
        )
        #expect(profile == .ansi)
    }

    @Test func comparable() {
        #expect(ColorProfile.noColor < ColorProfile.ansi)
        #expect(ColorProfile.ansi < ColorProfile.ansi256)
        #expect(ColorProfile.ansi256 < ColorProfile.trueColor)
    }
}

@Suite("ColorDownsampling")
struct ColorDownsamplingTests {
    @Test func trueColorUnchangedAtTrueColor() {
        let color = Color.trueColor(r: 200, g: 50, b: 50)
        #expect(color.downsampled(to: .trueColor) == color)
    }

    @Test func noColorReturnsNil() {
        let color = Color.trueColor(r: 200, g: 50, b: 50)
        #expect(color.downsampled(to: .noColor) == nil)
    }

    @Test func ansiDownsampleReturnsAnsiCase() {
        let color = Color.trueColor(r: 255, g: 0, b: 0)
        let result = color.downsampled(to: .ansi)
        if case .ansi? = result {
            // Good — downsampled to ANSI 16
        } else {
            #expect(Bool(false), "Expected .ansi case, got \(String(describing: result))")
        }
    }

    @Test func ansi256DownsampleReturnsExtendedCase() {
        let color = Color.trueColor(r: 100, g: 200, b: 100)
        let result = color.downsampled(to: .ansi256)
        if case .extended? = result {
            // Good — downsampled to 256-color palette
        } else {
            #expect(Bool(false), "Expected .extended case, got \(String(describing: result))")
        }
    }

    @Test func pureRedDownsamplesToAnsiRed() {
        let color = Color.trueColor(r: 255, g: 0, b: 0)
        let result = color.downsampled(to: .ansi)
        // Should map to bright red (index 9) which is closest to (255,0,0)
        #expect(result == .ansi(.brightRed))
    }

    @Test func ansiColorSurvivesTrueColorProfile() {
        let color = Color.ansi(.cyan)
        #expect(color.downsampled(to: .trueColor) == color)
    }
}

@Suite("ProfileAwareRendering")
struct ProfileAwareRenderingTests {
    @Test func noColorStripsEverything() {
        let style = Style().foreground(.trueColor(r: 255, g: 0, b: 0)).bold()
        let result = style.render("hello", profile: .noColor)
        #expect(result == "hello")
    }

    @Test func trueColorProfileIsDefault() {
        let style = Style().foreground(.trueColor(r: 255, g: 128, b: 0))
        let defaultResult = style.render("test")
        let explicitResult = style.render("test", profile: .trueColor)
        #expect(defaultResult == explicitResult)
    }

    @Test func ansiProfileProduces16ColorCode() {
        let style = Style().foreground(.trueColor(r: 255, g: 0, b: 0))
        let result = style.render("red", profile: .ansi)
        // Should contain a basic ANSI color code (30-37 or 90-97), not 38;2;...
        #expect(!result.contains("38;2;"))
        #expect(!result.contains("38;5;"))
    }

    @Test func ansi256ProfileProducesExtendedCode() {
        let style = Style().foreground(.trueColor(r: 100, g: 200, b: 100))
        let result = style.render("green", profile: .ansi256)
        // Should contain extended color code 38;5;N, not 38;2;...
        #expect(!result.contains("38;2;"))
        #expect(result.contains("38;5;"))
    }

    @Test func boldPreservedAtAllProfiles() {
        let style = Style().bold()
        for profile in [ColorProfile.ansi, .ansi256, .trueColor] {
            let result = style.render("bold", profile: profile)
            #expect(result.contains("1"))
        }
    }
}

@Suite("KeyBinding")
struct KeyBindingTests {
    @Test func runeMatch() {
        let binding = KeyBinding(.rune("q"))
        let msg = KeyMsg(type: .runes, runes: ["q"])
        #expect(binding.matches(msg))
    }

    @Test func runeNoMatch() {
        let binding = KeyBinding(.rune("q"))
        let msg = KeyMsg(type: .runes, runes: ["x"])
        #expect(!binding.matches(msg))
    }

    @Test func typeMatch() {
        let binding = KeyBinding(.type(.enter))
        let msg = KeyMsg(type: .enter)
        #expect(binding.matches(msg))
    }

    @Test func disabledDoesNotMatch() {
        var binding = KeyBinding(.rune("q"))
        binding.isEnabled = false
        let msg = KeyMsg(type: .runes, runes: ["q"])
        #expect(!binding.matches(msg))
    }

    @Test func multiplePatterns() {
        let binding = KeyBinding(.rune("q"), .type(.ctrl("c")))
        let q = KeyMsg(type: .runes, runes: ["q"])
        let ctrlC = KeyMsg(type: .ctrl("c"))
        #expect(binding.matches(q))
        #expect(binding.matches(ctrlC))
    }

    @Test func altRuneMatch() {
        let binding = KeyBinding(.runeWithAlt("x"))
        let msg = KeyMsg(type: .runes, runes: ["x"], alt: true)
        #expect(binding.matches(msg))
    }

    @Test func matchesFreeFunction() {
        let quit = KeyBinding(.rune("q"))
        let help = KeyBinding(.rune("?"))
        let msg = KeyMsg(type: .runes, runes: ["q"])
        #expect(matches(msg, quit, help))
    }
}

@Suite("Spinner")
struct SpinnerTests {
    @Test func initializeReturnsCommand() {
        let spinner = Spinner(type: .dot)
        let cmd = spinner.initialize()
        #expect(cmd != nil)
    }

    @Test func viewReturnsFrame() {
        let spinner = Spinner(type: .line)
        let view = spinner.view().content
        #expect(view == "|") // first frame of line spinner
    }
}

@Suite("Timer")
struct TimerTests {
    @Test func viewFormatsTime() {
        let timer = SpiceTimer(timeout: .seconds(90))
        #expect(timer.view().content == "1m30s")
    }

    @Test func startSetsRunning() {
        var timer = SpiceTimer(timeout: .seconds(10))
        _ = timer.start()
        #expect(timer.isRunning)
    }

    @Test func stopClearsRunning() {
        var timer = SpiceTimer(timeout: .seconds(10))
        _ = timer.start()
        _ = timer.stop()
        #expect(!timer.isRunning)
    }
}

@Suite("Stopwatch")
struct StopwatchTests {
    @Test func initialElapsedIsZero() {
        let sw = Stopwatch()
        #expect(sw.elapsed == .zero)
    }

    @Test func viewFormatsZero() {
        let sw = Stopwatch()
        #expect(sw.view().content == "0s")
    }
}

@Suite("Progress")
struct ProgressTests {
    @Test func viewAtZero() {
        let progress = Progress(width: 10, showPercentage: false)
        let view = progress.viewAs(0.0)
        #expect(view == String(repeating: "░", count: 10))
    }

    @Test func viewAtFull() {
        let progress = Progress(width: 10, showPercentage: false)
        let view = progress.viewAs(1.0)
        #expect(view == String(repeating: "█", count: 10))
    }

    @Test func viewAtHalf() {
        let progress = Progress(width: 10, showPercentage: false)
        let view = progress.viewAs(0.5)
        #expect(view == String(repeating: "█", count: 5) + String(repeating: "░", count: 5))
    }

    @Test func percentageDisplay() {
        let progress = Progress(width: 10)
        let view = progress.viewAs(0.5)
        #expect(view.contains("50%"))
    }
}

@Suite("Paginator")
struct PaginatorTests {
    @Test func dotView() {
        let pag = Paginator(type: .dots, perPage: 5, totalItems: 20)
        let view = pag.view().content
        #expect(view == "● ○ ○ ○")
    }

    @Test func arabicView() {
        var pag = Paginator(type: .arabic, perPage: 5, totalItems: 20)
        pag.nextPage()
        let view = pag.view().content
        #expect(view == "2/4")
    }

    @Test func sliceBounds() {
        let pag = Paginator(perPage: 10, totalItems: 25)
        let bounds = pag.sliceBounds(totalItems: 25)
        #expect(bounds == 0..<10)
    }

    @Test func navigation() {
        var pag = Paginator(perPage: 10, totalItems: 30)
        #expect(pag.onFirstPage)
        pag.nextPage()
        #expect(pag.page == 1)
        #expect(!pag.onFirstPage)
        pag.nextPage()
        #expect(pag.onLastPage)
        pag.nextPage() // should not go past last
        #expect(pag.page == 2)
    }
}

@Suite("Viewport")
struct ViewportTests {
    @Test func setContentAndView() {
        var vp = Viewport(width: 10, height: 3)
        vp.setContent("line1\nline2\nline3\nline4\nline5")
        let view = vp.view().content
        #expect(view.contains("line1"))
        #expect(view.contains("line3"))
        #expect(!view.contains("line4"))
    }

    @Test func scrollDown() {
        var vp = Viewport(width: 10, height: 2)
        vp.setContent("a\nb\nc\nd")
        vp.scrollDown()
        let view = vp.view().content
        #expect(view.contains("b"))
        #expect(!view.contains("a"))
    }

    @Test func scrollPercent() {
        var vp = Viewport(width: 10, height: 2)
        vp.setContent("a\nb\nc\nd")
        #expect(vp.scrollPercent == 0.0)
        vp.gotoBottom()
        #expect(vp.scrollPercent == 1.0)
    }
}

@Suite("TextInput")
struct TextInputTests {
    @Test func setAndGetValue() {
        var input = TextInput()
        input.setValue("hello")
        #expect(input.value == "hello")
    }

    @Test func charLimit() {
        var input = TextInput()
        input.charLimit = 5
        input.setValue("hello world")
        #expect(input.value == "hello")
    }

    @Test func focusAndBlur() {
        var input = TextInput()
        _ = input.focus()
        #expect(input.isFocused)
        input.blur()
        #expect(!input.isFocused)
    }
}

@Suite("Table")
struct TableTests {
    @Test func basicRendering() {
        let cols = [TableColumn(title: "Name", width: 10)]
        let rows: [TableRow] = [["Alice"], ["Bob"]]
        var table = Table(columns: cols, rows: rows, height: 5)
        table.focus()
        let view = table.view().content
        #expect(view.contains("Name"))
        #expect(view.contains("Alice"))
        #expect(view.contains("Bob"))
    }

    @Test func selectedRow() {
        let cols = [TableColumn(title: "X", width: 5)]
        let rows: [TableRow] = [["A"], ["B"], ["C"]]
        var table = Table(columns: cols, rows: rows)
        table.focus()
        table.setCursor(1)
        #expect(table.selectedRow == ["B"])
    }
}

@Suite("List")
struct ListTests {
    struct SimpleItem: ListItem {
        let name: String
        func filterValue() -> String { name }
    }

    @Test func basicCreation() {
        let items: [any ListItem] = [SimpleItem(name: "A"), SimpleItem(name: "B")]
        let list = List(items: items)
        #expect(list.items.count == 2)
    }

    @Test func selectedItem() {
        let items: [any ListItem] = [SimpleItem(name: "X"), SimpleItem(name: "Y")]
        let list = List(items: items)
        #expect(list.selectedItem?.filterValue() == "X")
    }
}

@Suite("SelectableList")
struct SelectableListTests {
    struct Fruit: ListItem {
        let name: String
        func filterValue() -> String { name }
    }

    private func makeItems(_ names: String...) -> [any ListItem] {
        names.map { Fruit(name: $0) }
    }

    // MARK: Initialization

    @Test func emptyListHasNoCursor() {
        let list = SelectableList()
        #expect(list.cursorItem == nil)
        #expect(list.selectedIndices.isEmpty)
    }

    @Test func itemsAreStoredInOrder() {
        let list = SelectableList(items: makeItems("Apple", "Banana", "Cherry"))
        #expect(list.items.count == 3)
        #expect(list.items[1].filterValue() == "Banana")
    }

    @Test func defaultRunesAreCircles() {
        let styles = SelectableListStyles()
        #expect(styles.unselectedRune == "○")
        #expect(styles.selectedRune == "●")
    }

    // MARK: Navigation

    @Test func cursorStartsAtZero() {
        let list = SelectableList(items: makeItems("A", "B", "C"))
        #expect(list.cursorIndex == 0)
        #expect(list.cursorItem?.filterValue() == "A")
    }

    @Test func cursorDownAdvancesOne() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        _ = list.update(KeyMsg(type: .down))
        #expect(list.cursorIndex == 1)
    }

    @Test func cursorUpDecrements() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        _ = list.update(KeyMsg(type: .down))
        _ = list.update(KeyMsg(type: .up))
        #expect(list.cursorIndex == 0)
    }

    @Test func cursorDoesNotGoBelowZero() {
        var list = SelectableList(items: makeItems("A", "B"))
        _ = list.update(KeyMsg(type: .up))
        #expect(list.cursorIndex == 0)
    }

    @Test func cursorDoesNotExceedLastItem() {
        var list = SelectableList(items: makeItems("A", "B"))
        _ = list.update(KeyMsg(type: .down))
        _ = list.update(KeyMsg(type: .down))
        _ = list.update(KeyMsg(type: .down))
        #expect(list.cursorIndex == 1)
    }

    @Test func viBindingsWork() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        _ = list.update(KeyMsg(type: .runes, runes: ["j"]))
        #expect(list.cursorIndex == 1)
        _ = list.update(KeyMsg(type: .runes, runes: ["k"]))
        #expect(list.cursorIndex == 0)
    }

    @Test func infiniteScrollingWrapsDown() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        list.infiniteScrolling = true
        _ = list.update(KeyMsg(type: .down))
        _ = list.update(KeyMsg(type: .down))
        _ = list.update(KeyMsg(type: .down)) // wraps back to 0
        #expect(list.cursorIndex == 0)
    }

    @Test func infiniteScrollingWrapsUp() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        list.infiniteScrolling = true
        _ = list.update(KeyMsg(type: .up)) // wraps to last
        #expect(list.cursorIndex == 2)
    }

    // MARK: Selection

    @Test func spaceTogglesSelection() {
        var list = SelectableList(items: makeItems("A", "B"))
        _ = list.update(KeyMsg(type: .space))
        #expect(list.selectedIndices.contains(0))
        _ = list.update(KeyMsg(type: .space))
        #expect(!list.selectedIndices.contains(0))
    }

    @Test func selectedItemsReturnInIndexOrder() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        _ = list.update(KeyMsg(type: .down))
        _ = list.update(KeyMsg(type: .space)) // select index 1
        _ = list.update(KeyMsg(type: .up))
        _ = list.update(KeyMsg(type: .space)) // select index 0
        let names = list.selectedItems.map { $0.filterValue() }
        #expect(names == ["A", "B"])
    }

    @Test func selectAllSelectsEverything() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        _ = list.update(KeyMsg(type: .ctrl("a")))
        #expect(list.selectedIndices.count == 3)
    }

    @Test func deselectAllClearsSelection() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        list.selectAll()
        _ = list.update(KeyMsg(type: .escape))
        #expect(list.selectedIndices.isEmpty)
    }

    @Test func toggleSelectionAtIndex() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        list.toggleSelection(at: 2)
        #expect(list.selectedIndices == [2])
        list.toggleSelection(at: 2)
        #expect(list.selectedIndices.isEmpty)
    }

    @Test func toggleOutOfRangeIsNoop() {
        var list = SelectableList(items: makeItems("A"))
        list.toggleSelection(at: 99)
        #expect(list.selectedIndices.isEmpty)
    }

    // MARK: setCursor / setItems

    @Test func setCursorClampsToRange() {
        var list = SelectableList(items: makeItems("A", "B", "C"))
        list.setCursor(100)
        #expect(list.cursorIndex == 2)
        list.setCursor(-5)
        #expect(list.cursorIndex == 0)
    }

    @Test func setItemsResetsState() {
        var list = SelectableList(items: makeItems("A", "B"))
        list.selectAll()
        _ = list.update(KeyMsg(type: .down))
        list.setItems(makeItems("X", "Y", "Z"))
        #expect(list.cursorIndex == 0)
        #expect(list.selectedIndices.isEmpty)
        #expect(list.items.count == 3)
    }

    // MARK: Scrolling

    @Test func viewportScrollsWithCursor() {
        var list = SelectableList(items: makeItems("A", "B", "C", "D", "E"), height: 2)
        // Move cursor to index 3
        for _ in 0..<3 { _ = list.update(KeyMsg(type: .down)) }
        let output = list.view().content
        #expect(output.contains("D"))
        #expect(!output.contains("A"))
    }

    @Test func viewportScrollsBackUp() {
        var list = SelectableList(items: makeItems("A", "B", "C", "D", "E"), height: 2)
        for _ in 0..<4 { _ = list.update(KeyMsg(type: .down)) }
        for _ in 0..<4 { _ = list.update(KeyMsg(type: .up)) }
        let output = list.view().content
        #expect(output.contains("A"))
    }

    // MARK: View rendering

    @Test func viewContainsUnselectedRuneByDefault() {
        let list = SelectableList(items: makeItems("Alpha"))
        let output = list.view().content
        #expect(output.contains("○"))
    }

    @Test func viewContainsSelectedRuneWhenSelected() {
        var list = SelectableList(items: makeItems("Alpha"))
        _ = list.update(KeyMsg(type: .space))
        let output = list.view().content
        #expect(output.contains("●"))
    }

    @Test func viewShowsNoItemsWhenEmpty() {
        let list = SelectableList()
        let output = list.view().content
        #expect(output.contains("No items."))
    }

    @Test func viewRendersAllVisibleItems() {
        let list = SelectableList(items: makeItems("Apple", "Banana", "Cherry"), height: 10)
        let output = list.view().content
        #expect(output.contains("Apple"))
        #expect(output.contains("Banana"))
        #expect(output.contains("Cherry"))
    }

    @Test func customRunesAppearInView() {
        var list = SelectableList(items: makeItems("Item"))
        list.styles.selectedRune = "✓"
        list.styles.unselectedRune = "✗"
        _ = list.update(KeyMsg(type: .space))
        let output = list.view().content
        #expect(output.contains("✓"))
    }

    @Test func longItemTextIsTruncated() {
        let longName = String(repeating: "x", count: 100)
        let list = SelectableList(items: makeItems(longName), width: 10)
        let output = list.view().content
        // Output must be truncated — raw name should not appear verbatim
        #expect(!output.contains(longName))
        #expect(output.contains("…"))
    }

    // MARK: Quit commands

    @Test func quitBindingReturnsQuit() {
        var list = SelectableList(items: makeItems("A"))
        let cmd = list.update(KeyMsg(type: .runes, runes: ["q"]))
        #expect(cmd != nil)
        if case .quit = cmd! { } else {
            #expect(Bool(false), "Expected .quit command")
        }
    }

    @Test func forceQuitReturnsQuit() {
        var list = SelectableList(items: makeItems("A"))
        let cmd = list.update(KeyMsg(type: .ctrl("c")))
        #expect(cmd != nil)
        if case .quit = cmd! { } else {
            #expect(Bool(false), "Expected .quit command")
        }
    }

    // MARK: Window resize

    @Test func windowSizeMsgUpdatesDimensions() {
        var list = SelectableList(items: makeItems("A", "B", "C", "D", "E"), height: 2)
        _ = list.update(WindowSizeMsg(width: 80, height: 20))
        // After resize to height 20 all items should be visible
        let output = list.view().content
        #expect(output.contains("E"))
    }

    // MARK: Initialize

    @Test func initializeReturnsNil() {
        let list = SelectableList()
        #expect(list.initialize() == nil)
    }
}

@Suite("Help")
struct HelpTests {
    struct TestKeyMap: HelpKeyMap {
        let up = KeyBinding(.type(.up), help: KeyHelp("↑", "up"))
        let down = KeyBinding(.type(.down), help: KeyHelp("↓", "down"))

        func shortHelp() -> [KeyBinding] { [up, down] }
        func fullHelp() -> [[KeyBinding]] { [[up, down]] }
    }

    @Test func shortHelpRenders() {
        let help = Help(width: 80)
        let view = help.view(keyMap: TestKeyMap())
        #expect(view.contains("up"))
        #expect(view.contains("down"))
    }
}
