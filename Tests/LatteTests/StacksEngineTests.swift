import Testing
import Chai
import Latte

// MARK: - Container engine tests
//
// `VStack`/`HStack` `_measure` (pure query) and `_embed` (allocation walk).
// Alignment offsets pin the exact fraction
// math — `Int(Double(shortage) * fraction)` — including `Int()` truncation on
// odd shortages, mirroring `aligned(toWidth:_:)` and `extendLines`.
//
// `visibleRows` (from `LayoutParity/ParityHarness.swift`) is the parity
// convention: zero-width cells skipped, wide cells counted once, trailing
// spaces stripped.

// MARK: - Measurement

@Suite("Stacks Engine Measurement")
struct StacksEngineMeasurementTests {

    @Test func vstackSizesToMaxChildWidthAndSumOfHeights() {
        let stack = VStack {
            Text("a")
            Text("bb")
            Text("ccc")
        }
        #expect(
            stack._measure(in: .unconstrained) == ViewSize(width: 3, height: 3)
        )
    }

    @Test func hstackSizesToSumOfWidthsAndMaxHeight() {
        let stack = HStack {
            Text("a")
            Text("bb")
            Text("ccc")
        }
        #expect(
            stack._measure(in: .unconstrained) == ViewSize(width: 6, height: 1)
        )
    }

    @Test func vstackIgnoresQueriedHeight() {
        // Children are measured with (width, nil): their heights stay ideal.
        let stack = VStack {
            Text("aa")
            Text("b")
        }
        #expect(
            stack._measure(in: AvailableSize(width: 10, height: 1)) == ViewSize(width: 2, height: 2)
        )
    }

    @Test func hstackIgnoresQueriedWidth() {
        let stack = HStack {
            Text("aa")
            Text("b")
        }
        #expect(
            stack._measure(in: AvailableSize(width: 1, height: 2)) == ViewSize(width: 3, height: 1)
        )
    }

    @Test func vstackSingleChildMeasuresChild() {
        let stack = VStack {
            Text("only")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 4, height: 1))
    }

    @Test func hstackSingleChildMeasuresChild() {
        let stack = HStack {
            Text("only")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 4, height: 1))
    }

    @Test func hstackColumnsMeasureAtIdealWidthSoTextCannotWrapInsideIt() {
        // Documented HStack column model: HStack measures columns at IDEAL
        // width — its query context is `(nil, height)`, and the allocation walk
        // gives each column its ideal-width rect — so a wrapping `Text` child
        // is inert inside an HStack; over-wide content overflows and is
        // truncated at the buffer.
        let stack = HStack {
            Text("abcdefghij")
        }
        #expect(
            stack._measure(in: AvailableSize(width: 5, height: nil)) == ViewSize(width: 10, height: 1)
        )
        let size = stack._measure(in: AvailableSize(width: 5, height: nil))
        var buffer = CellBuffer(width: 5, height: size.height)
        stack._embed(into: &buffer, at: ViewRect(size: size))
        #expect(visibleRows(buffer) == ["abcde"])
    }

    @Test func vstackEmptyChildrenMeasureZero() {
        #expect(VStack { Empty() }._measure(in: .unconstrained) == .zero)
        #expect(
            VStack {
                Empty()
                Empty()
            }._measure(in: .unconstrained) == .zero
        )
    }

    @Test func hstackEmptyChildrenMeasureZero() {
        #expect(
            HStack {
                Empty()
                Empty()
            }._measure(in: .unconstrained) == .zero
        )
    }

    @Test func vstackSkipsEmptyChildInMeasurement() {
        let stack = VStack {
            Text("a")
            Empty()
            Text("b")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 1, height: 2))
    }

    @Test func hstackSkipsEmptyChildInMeasurement() {
        let stack = HStack {
            Text("a")
            Empty()
            Text("b")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 2, height: 1))
    }

    @Test func hstackSpacerColumnsAdvanceWidth() {
        let stack = HStack {
            Text("a")
            Spacer(columns: 3)
            Text("b")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 5, height: 1))
    }

    @Test func vstackSpacerLinesAdvanceHeight() {
        let stack = VStack {
            Text("a")
            Spacer(lines: 2)
            Text("b")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 1, height: 4))
    }

    @Test func vstackMeasuresCjkChildWidth() {
        let stack = VStack {
            Text("你好")
            Text("ok")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 4, height: 2))
    }

    @Test func hstackMeasuresCjkChildWidth() {
        let stack = HStack {
            Text("你好")
            Text("!")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 5, height: 1))
    }

    @Test func nestedStacksCombineSizes() {
        let stack = HStack(alignment: .bottom) {
            Text("top\nmid")
            VStack {
                Text("a")
                Text("b")
            }
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 4, height: 2))
    }
}

// MARK: - Alignment fraction math

@Suite("Stacks Engine Alignment Offsets")
struct StacksEngineAlignmentTests {

    // MARK: Column offsets (VStack)

    @Test func vstackLeftKeepsChildFlushLeft() {
        var buffer = CellBuffer(width: 5, height: 2)
        let stack = VStack(alignment: .left) {
            Text("aa")
            Text("bbbbb")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 5, height: 2)))
        #expect(buffer[0, 0].character == "a")
        #expect(buffer[1, 0].character == "a")
        #expect(visibleRows(buffer) == ["aa", "bbbbb"])
    }

    @Test func vstackRightPlacesChildAtShortageOffset() {
        // Shortage 1, fraction 1.0 → offset 1. Single-line children keep the
        // block alignment unambiguous here.
        var buffer = CellBuffer(width: 3, height: 2)
        let stack = VStack(alignment: .right) {
            Text("ab")
            Text("abc")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 3, height: 2)))
        #expect(buffer[0, 0] == .empty)
        #expect(buffer[1, 0].character == "a")
        #expect(buffer[2, 0].character == "b")
        #expect(visibleRows(buffer) == [" ab", "abc"])
    }

    @Test func vstackRightLargerShortagePadsMore() {
        // Shortage 2, fraction 1.0 → offset 2.
        var buffer = CellBuffer(width: 4, height: 2)
        let stack = VStack(alignment: .right) {
            Text("ab")
            Text("cdef")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 4, height: 2)))
        #expect(buffer[0, 0] == .empty)
        #expect(buffer[1, 0] == .empty)
        #expect(buffer[2, 0].character == "a")
        #expect(buffer[3, 0].character == "b")
        #expect(visibleRows(buffer) == ["  ab", "cdef"])
    }

    @Test func vstackCenterTruncatesOddShortage() {
        // Shortage 3, fraction 0.5 → Int(1.5) = 1 (truncation, not rounding).
        var buffer = CellBuffer(width: 5, height: 2)
        let stack = VStack(alignment: .center) {
            Text("aa")
            Text("bbbbb")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 5, height: 2)))
        #expect(buffer[0, 0] == .empty)
        #expect(buffer[1, 0].character == "a")
        #expect(buffer[2, 0].character == "a")
        #expect(visibleRows(buffer) == [" aa", "bbbbb"])
    }

    @Test func vstackCenterEvenShortageSplitsEvenly() {
        // Shortage 4, fraction 0.5 → Int(2.0) = 2.
        var buffer = CellBuffer(width: 5, height: 1)
        let stack = VStack(alignment: .center) {
            Text("x")
            Text("xxxxx")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 5, height: 1)))
        #expect(buffer[0, 0] == .empty)
        #expect(buffer[1, 0] == .empty)
        #expect(buffer[2, 0].character == "x")
        #expect(visibleRows(buffer) == ["  x"])
    }

    // MARK: Row offsets (HStack)

    @Test func hstackTopKeepsChildFlushTop() {
        var buffer = CellBuffer(width: 2, height: 4)
        let stack = HStack {
            Text("a\nb\nc\nd")
            Text("x")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 2, height: 4)))
        #expect(buffer[1, 0].character == "x")
        #expect(visibleRows(buffer) == ["ax", "b", "c", "d"])
    }

    @Test func hstackBottomPlacesChildAtShortageOffset() {
        // Shortage 1, fraction 1.0 → offset 1.
        var buffer = CellBuffer(width: 2, height: 2)
        let stack = HStack(alignment: .bottom) {
            Text("a\nb")
            Text("1")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 2, height: 2)))
        // The left child occupies col 0 (rows 0–1); the right child "1" sits
        // at col 1, row 1 — the cell above it (col 1, row 0) stays empty.
        #expect(buffer[1, 0] == .empty)
        #expect(buffer[1, 1].character == "1")
        #expect(visibleRows(buffer) == ["a", "b1"])
    }

    @Test func hstackMiddleTruncatesOddShortage() {
        // Shortage 3, fraction 0.5 → Int(1.5) = 1 (truncation, not rounding).
        var buffer = CellBuffer(width: 2, height: 4)
        let stack = HStack(alignment: .middle) {
            Text("a\nb\nc\nd")
            Text("x")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 2, height: 4)))
        // The left child occupies col 0 (rows 0–3); the right child "x" is at
        // col 1, row 1 — the cell above it (col 1, row 0) stays empty.
        #expect(buffer[1, 0] == .empty)
        #expect(buffer[1, 1].character == "x")
        #expect(visibleRows(buffer) == ["a", "bx", "c", "d"])
    }

    @Test func hstackMiddleEvenShortageSplitsEvenly() {
        // Shortage 2, fraction 0.5 → Int(1.0) = 1.
        var buffer = CellBuffer(width: 2, height: 3)
        let stack = HStack(alignment: .middle) {
            Text("a\nb\nc")
            Text("x")
        }
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 2, height: 3)))
        // The left child occupies col 0 (rows 0–2); "x" is at col 1, row 1.
        #expect(buffer[1, 0] == .empty)
        #expect(buffer[1, 2] == .empty)
        #expect(buffer[1, 1].character == "x")
        #expect(visibleRows(buffer) == ["a", "bx", "c"])
    }
}

// MARK: - Render behavior

@Suite("Stacks Engine Render")
struct StacksEngineRenderTests {

    @Test func vstackSequencesChildrenByRow() {
        let buffer = embedBuffer(
            VStack {
                Text("aa")
                Text("b")
            },
            width: 2
        )
        #expect(visibleRows(buffer) == ["aa", "b"])
    }

    @Test func hstackSequencesChildrenByColumn() {
        let buffer = embedBuffer(
            HStack {
                Text("a")
                Text("bb")
            },
            width: 3
        )
        #expect(visibleRows(buffer) == ["abb"])
    }

    @Test func vstackEmptyChildAdvancesNothing() {
        let buffer = embedBuffer(
            VStack {
                Text("a")
                Empty()
                Text("b")
            },
            width: 1
        )
        // Height 2: the empty child contributes no row.
        #expect(buffer.height == 2)
        #expect(visibleRows(buffer) == ["a", "b"])
    }

    @Test func hstackEmptyChildAdvancesNothing() {
        let buffer = embedBuffer(
            HStack {
                Text("a")
                Empty()
                Text("b")
            },
            width: 3
        )
        // Width 2: the empty child contributes no column.
        #expect(visibleRows(buffer) == ["ab"])
    }

    @Test func vstackSpacerLinesProducesExactlyEmptyRows() {
        let buffer = embedBuffer(
            VStack {
                Text("a")
                Spacer(lines: 2)
                Text("b")
            },
            width: 2
        )
        #expect(visibleRows(buffer) == ["a", "", "", "b"])
    }

    @Test func hstackSpacerColumnsAdvancesColumns() {
        let buffer = embedBuffer(
            HStack {
                Text("a")
                Spacer(columns: 3)
                Text("b")
            },
            width: 5
        )
        #expect(visibleRows(buffer) == ["a   b"])
    }

    @Test func hstackAdvancesByCjkChildWidth() {
        let buffer = embedBuffer(
            HStack {
                Text("你好")
                Text("!")
            },
            width: 5
        )
        // 你好 occupies 4 columns with a continuation cell; "!" lands at col 4.
        #expect(buffer[4, 0].character == "!")
        #expect(visibleRows(buffer) == ["你好!"])
    }

    @Test func vstackRendersCjkChild() {
        let buffer = embedBuffer(
            VStack {
                Text("你好")
                Text("ok")
            },
            width: 4
        )
        #expect(visibleRows(buffer) == ["你好", "ok"])
    }

    @Test func hstackNestsVstackBottomAligned() {
        let buffer = embedBuffer(
            HStack(alignment: .bottom) {
                Text("top\nmid")
                VStack {
                    Text("a")
                    Text("b")
                }
            },
            width: 4
        )
        #expect(visibleRows(buffer) == ["topa", "midb"])
    }

    @Test func threeLevelNestingThroughStructuralChildren() {
        // The middle HStack's for-loop flattens through the VStack into the
        // outer HStack layout: the VStack (ordinary composite) is one child.
        let buffer = embedBuffer(
            HStack {
                VStack {
                    HStack {
                        Text("a")
                        Text("b")
                    }
                    HStack {
                        Text("c")
                        for item in ["d", "e"] {
                            Text(item)
                        }
                    }
                }
                Text("z")
            },
            width: 8
        )
        #expect(visibleRows(buffer) == ["ab z", "cde"])
    }
}

// MARK: - Allocation assignment

@Suite("Stacks Engine Allocation Assignment")
struct StacksEngineAllocationAssignmentTests {

    @Test func vstackAllocatesEachChildItsOwnRect() {
        var buffer = CellBuffer(width: 20, height: 2)
        let stack = VStack {
            RectEchoView()
            Text("hi")
        }
        // The stack is assigned 20 columns (the root rect), but it shrink-wraps
        // to its children: the echo reports 12, so it is allocated a 12-wide
        // rect and observes "W:12" — the container's rect is not a child's.
        stack._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 20, height: 2))
        )
        #expect(visibleRows(buffer) == ["W:12", "hi"])
    }

    @Test func vstackPlacementUsesTheOccupiedWidth() {
        var buffer = CellBuffer(width: 12, height: 2)
        let stack = VStack(alignment: .right) {
            RectEchoView()
            Text("hi")
        }
        // Occupied width 12: the echo fills it (shortage 0 → col 0); "hi"
        // right-aligns within 12 → col 10. Placement never consults the parent
        // container's rect beyond the occupied width.
        stack._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 12, height: 2))
        )
        #expect(buffer[0, 0].character == "W")
        #expect(buffer[8, 0] == .empty)
        #expect(buffer[10, 1].character == "h")
    }
}
