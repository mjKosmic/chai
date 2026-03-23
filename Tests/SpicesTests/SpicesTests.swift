import Testing
@testable import Spices
import Chai

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
        let view = spinner.view().content.plainText
        #expect(view == "|") // first frame of line spinner
    }
}

@Suite("Timer")
struct TimerTests {
    @Test func viewFormatsTime() {
        let timer = SpiceTimer(timeout: .seconds(90))
        #expect(timer.view().content.plainText == "1m30s")
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
        #expect(sw.view().content.plainText == "0s")
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
        let view = pag.view().content.plainText
        #expect(view == "● ○ ○ ○")
    }

    @Test func arabicView() {
        var pag = Paginator(type: .arabic, perPage: 5, totalItems: 20)
        pag.nextPage()
        let view = pag.view().content.plainText
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
        let view = vp.view().content.plainText
        #expect(view.contains("line1"))
        #expect(view.contains("line3"))
        #expect(!view.contains("line4"))
    }

    @Test func scrollDown() {
        var vp = Viewport(width: 10, height: 2)
        vp.setContent("a\nb\nc\nd")
        vp.scrollDown()
        let view = vp.view().content.plainText
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
        let view = table.view().content.plainText
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
        let output = list.view().content.plainText
        #expect(output.contains("D"))
        #expect(!output.contains("A"))
    }

    @Test func viewportScrollsBackUp() {
        var list = SelectableList(items: makeItems("A", "B", "C", "D", "E"), height: 2)
        for _ in 0..<4 { _ = list.update(KeyMsg(type: .down)) }
        for _ in 0..<4 { _ = list.update(KeyMsg(type: .up)) }
        let output = list.view().content.plainText
        #expect(output.contains("A"))
    }

    // MARK: View rendering

    @Test func viewContainsUnselectedRuneByDefault() {
        let list = SelectableList(items: makeItems("Alpha"))
        let output = list.view().content.plainText
        #expect(output.contains("○"))
    }

    @Test func viewContainsSelectedRuneWhenSelected() {
        var list = SelectableList(items: makeItems("Alpha"))
        _ = list.update(KeyMsg(type: .space))
        let output = list.view().content.plainText
        #expect(output.contains("●"))
    }

    @Test func viewShowsNoItemsWhenEmpty() {
        let list = SelectableList()
        let output = list.view().content.plainText
        #expect(output.contains("No items."))
    }

    @Test func viewRendersAllVisibleItems() {
        let list = SelectableList(items: makeItems("Apple", "Banana", "Cherry"), height: 10)
        let output = list.view().content.plainText
        #expect(output.contains("Apple"))
        #expect(output.contains("Banana"))
        #expect(output.contains("Cherry"))
    }

    @Test func customRunesAppearInView() {
        var list = SelectableList(items: makeItems("Item"))
        list.styles.selectedRune = "✓"
        list.styles.unselectedRune = "✗"
        _ = list.update(KeyMsg(type: .space))
        let output = list.view().content.plainText
        #expect(output.contains("✓"))
    }

    @Test func longItemTextIsTruncated() {
        let longName = String(repeating: "x", count: 100)
        let list = SelectableList(items: makeItems(longName), width: 10)
        let output = list.view().content.plainText
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
        let output = list.view().content.plainText
        #expect(output.contains("E"))
    }

    // MARK: Initialize

    @Test func initializeReturnsNil() {
        let list = SelectableList()
        #expect(list.initialize() == nil)
    }
}

@Suite("Menu")
struct MenuTests {
    struct Option: ListItem {
        let name: String
        func filterValue() -> String { name }
    }

    private func makeItems(_ names: String...) -> [any ListItem] {
        names.map { Option(name: $0) }
    }

    // MARK: 6.1 Initialization

    @Test func emptyMenuHasNoCursorItem() {
        let menu = Menu()
        #expect(menu.cursorItem == nil)
    }

    @Test func itemsStoredInOrder() {
        let menu = Menu(items: makeItems("A", "B", "C"))
        #expect(menu.items.count == 3)
        #expect(menu.items[1].filterValue() == "B")
    }

    @Test func defaultCursorRune() {
        let styles = MenuStyles()
        #expect(styles.cursorRune == ">")
    }

    // MARK: 6.2 Navigation

    @Test func cursorStartsAtZero() {
        let menu = Menu(items: makeItems("A", "B", "C"))
        #expect(menu.cursorIndex == 0)
        #expect(menu.cursorItem?.filterValue() == "A")
    }

    @Test func cursorDownAdvancesOne() {
        var menu = Menu(items: makeItems("A", "B", "C"))
        _ = menu.update(KeyMsg(type: .down))
        #expect(menu.cursorIndex == 1)
    }

    @Test func cursorUpDecrements() {
        var menu = Menu(items: makeItems("A", "B", "C"))
        _ = menu.update(KeyMsg(type: .down))
        _ = menu.update(KeyMsg(type: .up))
        #expect(menu.cursorIndex == 0)
    }

    @Test func cursorDoesNotGoBelowZero() {
        var menu = Menu(items: makeItems("A", "B"))
        _ = menu.update(KeyMsg(type: .up))
        #expect(menu.cursorIndex == 0)
    }

    @Test func cursorDoesNotExceedLastItem() {
        var menu = Menu(items: makeItems("A", "B"))
        _ = menu.update(KeyMsg(type: .down))
        _ = menu.update(KeyMsg(type: .down))
        _ = menu.update(KeyMsg(type: .down))
        #expect(menu.cursorIndex == 1)
    }

    @Test func viBindingsWork() {
        var menu = Menu(items: makeItems("A", "B", "C"))
        _ = menu.update(KeyMsg(type: .runes, runes: ["j"]))
        #expect(menu.cursorIndex == 1)
        _ = menu.update(KeyMsg(type: .runes, runes: ["k"]))
        #expect(menu.cursorIndex == 0)
    }

    @Test func infiniteScrollingWrapsDown() {
        var menu = Menu(items: makeItems("A", "B", "C"))
        menu.infiniteScrolling = true
        _ = menu.update(KeyMsg(type: .down))
        _ = menu.update(KeyMsg(type: .down))
        _ = menu.update(KeyMsg(type: .down)) // wraps back to 0
        #expect(menu.cursorIndex == 0)
    }

    @Test func infiniteScrollingWrapsUp() {
        var menu = Menu(items: makeItems("A", "B", "C"))
        menu.infiniteScrolling = true
        _ = menu.update(KeyMsg(type: .up)) // wraps to last
        #expect(menu.cursorIndex == 2)
    }

    // MARK: 6.3 Confirmation

    @Test func enterSetsConfirmedAndPostsSelectionMsg() async throws {
        var menu = Menu(items: makeItems("A", "B"))
        let menuID = menu.id
        let cmd = menu.update(KeyMsg(type: .enter))
        #expect(menu.isConfirmed)
        guard case .perform(let work) = cmd else {
            #expect(Bool(false), "Expected .perform command"); return
        }
        let msg = await work()
        let selection = try #require(msg as? MenuSelectionMsg)
        #expect(selection.menuID == menuID)
        #expect(selection.item.filterValue() == "A")
    }

    @Test func selectedItemIsNilBeforeConfirm() {
        let menu = Menu(items: makeItems("A", "B"))
        #expect(menu.selectedItem == nil)
    }

    @Test func selectedItemMatchesCursorAfterConfirm() {
        var menu = Menu(items: makeItems("A", "B", "C"))
        _ = menu.update(KeyMsg(type: .down)) // cursor at 1
        _ = menu.update(KeyMsg(type: .enter))
        #expect(menu.selectedItem?.filterValue() == "B")
    }

    // MARK: 6.4 Cancellation

    @Test func escapePostsCancellationMsg() async throws {
        var menu = Menu(items: makeItems("A"))
        let menuID = menu.id
        let cmd = menu.update(KeyMsg(type: .escape))
        #expect(!menu.isConfirmed)
        guard case .perform(let work) = cmd else {
            #expect(Bool(false), "Expected .perform command"); return
        }
        let msg = await work()
        let cancellation = try #require(msg as? MenuCancellationMsg)
        #expect(cancellation.menuID == menuID)
    }

    @Test func quitPostsCancellationMsg() async throws {
        var menu = Menu(items: makeItems("A"))
        let menuID = menu.id
        let cmd = menu.update(KeyMsg(type: .runes, runes: ["q"]))
        #expect(!menu.isConfirmed)
        guard case .perform(let work) = cmd else {
            #expect(Bool(false), "Expected .perform command"); return
        }
        let msg = await work()
        let cancellation = try #require(msg as? MenuCancellationMsg)
        #expect(cancellation.menuID == menuID)
    }

    @Test func twoMenusHaveDistinctIDs() {
        let a = Menu(items: makeItems("X"))
        let b = Menu(items: makeItems("Y"))
        #expect(a.id != b.id)
    }

    @Test func ctrlCReturnsQuitNotConfirmed() {
        var menu = Menu(items: makeItems("A"))
        let cmd = menu.update(KeyMsg(type: .ctrl("c")))
        #expect(!menu.isConfirmed)
        if case .quit = cmd! { } else {
            #expect(Bool(false), "Expected .quit command")
        }
    }

    // MARK: 6.5 Scrolling

    @Test func viewportScrollsDownWithCursor() {
        var menu = Menu(items: makeItems("A", "B", "C", "D", "E"), height: 2)
        for _ in 0..<3 { _ = menu.update(KeyMsg(type: .down)) }
        let output = menu.view().content.plainText
        #expect(output.contains("D"))
        #expect(!output.contains("A"))
    }

    @Test func viewportScrollsBackUp() {
        var menu = Menu(items: makeItems("A", "B", "C", "D", "E"), height: 2)
        for _ in 0..<4 { _ = menu.update(KeyMsg(type: .down)) }
        for _ in 0..<4 { _ = menu.update(KeyMsg(type: .up)) }
        let output = menu.view().content.plainText
        #expect(output.contains("A"))
    }

    @Test func windowSizeMsgUpdatesDimensions() {
        var menu = Menu(items: makeItems("A", "B", "C", "D", "E"), height: 2)
        _ = menu.update(WindowSizeMsg(width: 80, height: 20))
        let output = menu.view().content.plainText
        #expect(output.contains("E"))
    }

    // MARK: 6.6 View rendering

    @Test func cursorRuneAppearsOnFocusedRow() {
        let menu = Menu(items: makeItems("Alpha", "Beta"))
        let output = menu.view().content.plainText
        #expect(output.contains(">"))
    }

    @Test func onlyOneCursorRuneForThreeItems() {
        let menu = Menu(items: makeItems("A", "B", "C"))
        let output = menu.view().content.plainText
        let count = output.filter { $0 == ">" }.count
        #expect(count == 1)
    }

    @Test func viewShowsNoItemsWhenEmpty() {
        let menu = Menu()
        let output = menu.view().content.plainText
        #expect(output.contains("No items."))
    }

    @Test func viewRendersAllVisibleItems() {
        let menu = Menu(items: makeItems("Apple", "Banana", "Cherry"), height: 10)
        let output = menu.view().content.plainText
        #expect(output.contains("Apple"))
        #expect(output.contains("Banana"))
        #expect(output.contains("Cherry"))
    }

    @Test func customCursorRuneAppearsInView() {
        var menu = Menu(items: makeItems("Item"))
        menu.styles.cursorRune = "▶"
        let output = menu.view().content.plainText
        #expect(output.contains("▶"))
    }

    @Test func longItemTextIsTruncated() {
        let longName = String(repeating: "x", count: 100)
        let menu = Menu(items: makeItems(longName), width: 10)
        let output = menu.view().content.plainText
        #expect(!output.contains(longName))
        #expect(output.contains("…"))
    }

    @Test func initializeReturnsNil() {
        let menu = Menu()
        #expect(menu.initialize() == nil)
    }

    // MARK: 6.7 Mutation helpers

    @Test func setCursorClampsHigh() {
        var menu = Menu(items: makeItems("A", "B", "C"))
        menu.setCursor(100)
        #expect(menu.cursorIndex == 2)
    }

    @Test func setCursorClampsLow() {
        var menu = Menu(items: makeItems("A", "B", "C"))
        menu.setCursor(-5)
        #expect(menu.cursorIndex == 0)
    }

    @Test func setItemsResetsCursorAndConfirmed() {
        var menu = Menu(items: makeItems("A", "B"))
        _ = menu.update(KeyMsg(type: .down))
        _ = menu.update(KeyMsg(type: .enter)) // confirms
        menu.setItems(makeItems("X", "Y", "Z"))
        #expect(menu.cursorIndex == 0)
        #expect(!menu.isConfirmed)
        #expect(menu.items.count == 3)
    }
}

// MARK: - Milestone 7 additions

@Suite("Progress — Gradient Fill")
struct ProgressGradientTests {

    // 7.1 — fillGradient = nil reproduces solid-fill behavior
    @Test func fillGradientNilIsSolidFill() {
        var progress = Progress(width: 10, showPercentage: false)
        progress.fillGradient = nil
        let view = progress.viewAs(1.0)
        #expect(view == String(repeating: "█", count: 10))
    }

    // 7.1 — Single-stop array falls back to solid fill with that color
    @Test func fillGradientSingleColorFallsBackToSolid() {
        var progress = Progress(width: 4, showPercentage: false)
        progress.fillGradient = [.ansi(.red)]
        let view = progress.viewAs(1.0)
        // Must still produce 4 fill characters (color-coded, but structurally solid)
        let fillCount = view.unicodeScalars.filter { $0 == "█" }.count
        #expect(fillCount == 4)
        // Single ANSI color stop should still result in ANSI escape sequences
        #expect(view.contains("\u{1B}["))
    }

    // 7.1 — Two-color gradient produces ANSI output with fill characters
    @Test func fillGradientTwoColorProducesANSIOutput() {
        var progress = Progress(width: 6, fullColor: nil, showPercentage: false)
        progress.fillGradient = [.trueColor(r: 255, g: 0, b: 0), .trueColor(r: 0, g: 0, b: 255)]
        let view = progress.viewAs(1.0)
        // Must contain ANSI colour sequences
        #expect(view.contains("\u{1B}["))
        // Must contain the fill character for every filled column
        let fillCount = view.unicodeScalars.filter { $0 == "█" }.count
        #expect(fillCount == 6)
    }

    // 7.1 — fillGradient is recomputed per view() call (wider fill ⟹ more content)
    @Test func fillGradientIsRecomputedPerPercent() {
        var progress = Progress(width: 10, showPercentage: false)
        progress.fillGradient = [.trueColor(r: 255, g: 0, b: 0), .trueColor(r: 0, g: 0, b: 255)]
        let viewHalf = progress.viewAs(0.5)
        let viewFull = progress.viewAs(1.0)
        // Full bar has twice as many filled chars — compare filled glyph counts, not raw length
        let fillCountHalf = viewHalf.unicodeScalars.filter { $0 == "█" }.count
        let fillCountFull = viewFull.unicodeScalars.filter { $0 == "█" }.count
        #expect(fillCountFull == 2 * fillCountHalf)
    }

    // 7.1 — fillGradient takes precedence over gradientFrom / fullColor
    @Test func fillGradientTakesPrecedenceOverGradientFrom() {
        var progress = Progress(width: 4, fullColor: .ansi(.green), showPercentage: false)
        progress.gradientFrom = .ansi(.yellow)
        progress.fillGradient = [.trueColor(r: 255, g: 0, b: 0), .trueColor(r: 0, g: 0, b: 255)]
        let view = progress.viewAs(1.0)
        // Must still produce content — primarily verifying it does not crash and
        // fillGradient is used (the gradient contains custom trueColor values).
        #expect(view.contains("█"))
        #expect(view.contains("\u{1B}[38;2;"))   // trueColor SGR prefix
    }

    // C11 — Width-1 bar picks the LAST stop (t=1.0), matching renderGradient behavior
    @Test func fillGradientWidthOnePicksLastStop() {
        // With two stops: red → blue.  A 1-column bar should render blue (t=1.0).
        var progress = Progress(width: 1, showPercentage: false)
        progress.fillGradient = [
            .trueColor(r: 255, g: 0, b: 0),    // red  (t = 0.0)
            .trueColor(r: 0,   g: 0, b: 255),  // blue (t = 1.0)
        ]
        let view = progress.viewAs(1.0)
        // The single cell must be coloured with the last stop (blue: 0,0,255).
        #expect(view.contains("\u{1B}[38;2;0;0;255m"))
        #expect(!view.contains("\u{1B}[38;2;255;0;0m"))
    }

    // 7.1 — Multi-stop (3-color) gradient produces output for every filled char
    @Test func fillGradientThreeColorStops() {
        var progress = Progress(width: 9, showPercentage: false)
        progress.fillGradient = [
            .trueColor(r: 255, g: 0,   b: 0),   // red
            .trueColor(r: 0,   g: 255, b: 0),   // green
            .trueColor(r: 0,   g: 0,   b: 255), // blue
        ]
        let view = progress.viewAs(1.0)
        let fillCount = view.unicodeScalars.filter { $0 == "█" }.count
        #expect(fillCount == 9)
    }
}

@Suite("TextInput — Overflow Scrolling")
struct TextInputScrollingTests {

    // 7.2 — When text exceeds the width the cursor (last typed char) remains visible
    @Test func cursorRemainsVisibleWhenTextExceedsWidth() {
        var input = TextInput(width: 5)   // narrow field: prompt "> " (2) + 3 chars visible
        _ = input.focus()
        // Type 10 characters — far more than the 3 available after the prompt
        for c: Character in "ABCDEFGHIJ" {
            _ = input.update(KeyMsg(type: .runes, runes: [c]))
        }
        let view = input.view().content.plainText
        // The last typed character ('J') must be visible in the rendered output
        #expect(view.contains("J"))
    }

    // 7.2 — When the cursor moves back to the start, offset resets so 'A' is visible
    @Test func scrollOffsetResetsWhenCursorMovesLeft() {
        var input = TextInput(width: 6)
        _ = input.focus()
        for c: Character in "ABCDEFGH" {
            _ = input.update(KeyMsg(type: .runes, runes: [c]))
        }
        // Jump to line start
        _ = input.update(KeyMsg(type: .home))
        let view = input.view().content.plainText
        #expect(view.contains("A"))
    }

    // 7.2 — Pasted text (setValue) that overflows still scrolls to keep cursor visible
    @Test func pastedTextOverflowScrollsToEnd() {
        var input = TextInput(width: 5)
        _ = input.focus()
        input.setValue("Hello World")   // longer than the visible width
        let view = input.view().content.plainText
        // Cursor is at the end → last character 'd' must be visible
        #expect(view.contains("d"))
    }
}

@Suite("Viewport — Line Stability")
struct ViewportLineStabilityTests {

    // 7.3 — After a single-line scroll, overlapping lines are identical strings.
    //
    // Before scroll (yOffset=0): [line1, line2, line3]
    // After  scroll (yOffset=1): [line2, line3, line4]
    //
    // The content that remains visible (line2, line3) must produce exactly the
    // same padded strings in both frames — this is what lets the Renderer's
    // line-level diff skip those rows.
    @Test func scrollOneLineChangesOnlyOneLine() {
        var vp = Viewport(width: 10, height: 3)
        vp.setContent("line1\nline2\nline3\nline4\nline5")

        let before = vp.view().content.plainText.components(separatedBy: "\n")
        vp.scrollDown()
        let after = vp.view().content.plainText.components(separatedBy: "\n")

        #expect(before.count == 3)
        #expect(after.count == 3)

        // The overlapping rows must be string-equal between frames.
        //   before[1] ("line2…") == after[0]
        //   before[2] ("line3…") == after[1]
        #expect(after[0] == before[1])
        #expect(after[1] == before[2])

        // Only the newly revealed bottom line is genuinely new.
        #expect(after[2] != before[2])
    }
}

@Suite("Spinner — Built-in Presets")
struct SpinnerPresetTests {

    // 7.4 — All named presets from the roadmap exist and have non-empty frame sets
    @Test func allPresetsExistAndHaveFrames() {
        let presets: [SpinnerType] = [
            .dot, .line, .miniDot, .jump, .pulse, .globe,
        ]
        for preset in presets {
            #expect(!preset.frames.isEmpty)
            #expect(preset.interval > .zero)
        }
    }

    // 7.4 — Custom frame sets continue to work
    @Test func customFrameSetWorks() {
        let custom = SpinnerType(frames: ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"],
                                 interval: .milliseconds(100))
        var spinner = Spinner(type: custom)
        #expect(spinner.view().content.plainText == "→")   // first frame
        _ = spinner.update(SpinnerTickMsg(id: 0, tag: 0))  // won't advance (wrong id/tag)
        // Still first frame — but the type's frames are intact
        #expect(custom.frames.count == 8)
    }

    // 7.4 — dot preset matches the expected frame sequence
    @Test func dotPresetFrames() {
        let frames = SpinnerType.dot.frames
        #expect(frames.first == "⣾")
        #expect(frames.last  == "⣷")
    }

    // 7.4 — line preset matches the documented frames
    @Test func linePresetFrames() {
        let frames = SpinnerType.line.frames
        #expect(frames.contains("|"))
        #expect(frames.contains("/"))
        #expect(frames.contains("-"))
        #expect(frames.contains("\\"))
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
        // help.view() returns StyledText; check via plainText.
        #expect(view.plainText.contains("up"))
        #expect(view.plainText.contains("down"))
    }
}
