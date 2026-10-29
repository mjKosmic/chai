import Testing
import Chai

// MARK: - ZStack engine tests
//
// `ZStack` queries every child with the assigned width AND height, occupies the
// maximum report on each axis, and positions each child independently within
// that occupied box. `visibleRows` (from `LayoutParity/ParityHarness.swift`)
// is the parity convention: zero-width cells skipped, wide cells counted once,
// trailing spaces stripped.

// MARK: - Measurement

@Suite("ZStack Engine Measurement")
struct ZStackEngineMeasurementTests {

    @Test func largestChildDefinesBothAxes() {
        let stack = ZStack {
            Text("a\nb\nc")
            Text("abcde")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 5, height: 3))
    }

    @Test func singleChildMeasuresChild() {
        #expect(
            ZStack { Text("only") }._measure(in: .unconstrained) == ViewSize(width: 4, height: 1)
        )
    }

    @Test func emptyChildrenMeasureZero() {
        #expect(
            ZStack {
                Empty()
                Empty()
            }._measure(in: .unconstrained) == .zero
        )
    }

    @Test func queriesChildrenOnBothAxes() {
        let stack = ZStack {
            Text("abcdefgh")
            HeightEchoView()
        }
        // Text wraps at the 5-column width (2 rows); the echo reports the
        // 4-row height context, so the stack occupies 5×4.
        #expect(
            stack._measure(in: AvailableSize(width: 5, height: 4)) == ViewSize(width: 5, height: 4)
        )
    }

    @Test func zeroQueryReportsTheMinimumSize() {
        // At `.zero`, Text wraps to its minimum width (1 column for ASCII),
        // so the stack reports the max minimum width and height.
        #expect(ZStack { Text("abc") }._measure(in: .zero) == ViewSize(width: 1, height: 3))
    }

    @Test func fillGrowsToTheAssignedContext() {
        let stack = ZStack {
            Text("x")
            Fill()
        }
        #expect(
            stack._measure(in: AvailableSize(width: 8, height: 4)) == ViewSize(width: 8, height: 4)
        )
    }

    @Test func flexibleSpacerContributesNoSize() {
        let stack = ZStack {
            Text("abc")
            Spacer()
        }
        #expect(
            stack._measure(in: AvailableSize(width: 8, height: 4)) == ViewSize(width: 3, height: 1)
        )
    }

    @Test func cjkChildWidthIsMeasuredInDisplayColumns() {
        let stack = ZStack {
            Text("你好")
            Text("ok")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 4, height: 1))
    }

    @Test func nestedContainersCombineSizes() {
        let stack = ZStack {
            VStack {
                Text("a")
                Text("bb")
            }
            HStack {
                Text("ccc")
                Text("d")
            }
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 4, height: 2))
    }
}

// MARK: - Alignment

@Suite("ZStack Engine Alignment")
struct ZStackEngineAlignmentTests {

    @Test func centerIsTheDefault() {
        let buffer = embedBuffer(
            ZStack {
                Text("xxxx")
                Text("ab")
            },
            width: 6
        )
        // Occupied width 4; the 2-wide child has a shortage of 2, so
        // Int(2 × 0.5) = 1 column of leading offset.
        #expect(visibleRows(buffer) == ["xabx"])
    }

    @Test func topLeftKeepsChildFlushAtTheOrigin() {
        let buffer = embedBuffer(
            ZStack(alignment: .topLeft) {
                Text("xxxx")
                Text("ab")
            },
            width: 6
        )
        #expect(visibleRows(buffer) == ["abxx"])
    }

    @Test func bottomRightAlignsBothAxes() {
        let buffer = embedBuffer(
            ZStack(alignment: .bottomRight) {
                Text("aaaa\nbbbb")
                Text("xy")
            },
            width: 6
        )
        // The 2×1 child is placed at col 2, row 1 inside the 4×2 occupied box.
        #expect(visibleRows(buffer) == ["aaaa", "bbxy"])
    }

    @Test func oddHorizontalShortageTruncates() {
        let buffer = embedBuffer(
            ZStack {
                Text("xxxxx")
                Text("ab")
            },
            width: 6
        )
        // Shortage 3, center → Int(1.5) = 1, matching the stacks' truncation.
        #expect(visibleRows(buffer) == ["xabxx"])
    }

    @Test func oddVerticalShortageTruncates() {
        let buffer = embedBuffer(
            ZStack {
                Text("a\nb\nc\nd")
                Text("x")
            },
            width: 4
        )
        // Occupied 1×4; shortage 3, middle → Int(1.5) = 1, so "x" lands on row 1.
        #expect(visibleRows(buffer) == ["a", "x", "c", "d"])
    }

    @Test func customFractionalAlignmentPlacesChildProportionally() {
        let buffer = embedBuffer(
            ZStack(alignment: Alignment(
                horizontal: HorizontalAlignment(fraction: 0.25),
                vertical: .middle
            )) {
                Text("xxxxx")
                Text("a")
            },
            width: 6
        )
        // Occupied width 5; the 1-wide child has a shortage of 4, so
        // Int(4 × 0.25) = 1 column of leading offset.
        #expect(visibleRows(buffer) == ["xaxxx"])
    }

    @Test func multiLineChildIsOffsetAsOneBlock() {
        let buffer = embedBuffer(
            ZStack {
                Text("aaaa\nbbbb\ncccc\ndddd")
                Text("x\ny")
            },
            width: 4
        )
        // Shortage 2 vertically, middle → row 1; the whole 1×2 child moves
        // together, not each line independently.
        #expect(visibleRows(buffer) == ["aaaa", "bxbb", "cycc", "dddd"])
    }

    @Test func wideCharactersArePositionedByDisplayWidth() {
        let buffer = embedBuffer(
            ZStack(alignment: .right) {
                Text("你好")
                Text("ab")
            },
            width: 6
        )
        // "你好" occupies 4 display columns, so the 2-wide child starts at
        // col 2 — the right edge of the occupied box.
        #expect(visibleRows(buffer) == ["你ab"])
    }
}

// MARK: - Render

@Suite("ZStack Engine Render")
struct ZStackEngineRenderTests {

    @Test func declarationOrderPaintsLaterChildrenOnTop() {
        let buffer = embedBuffer(
            ZStack(alignment: .topLeft) {
                Text("aaaa")
                Text("bb")
            },
            width: 4
        )
        #expect(visibleRows(buffer) == ["bbaa"])
    }

    @Test func assignmentLargerThanContentDoesNotStretchChildren() {
        var buffer = CellBuffer(width: 8, height: 6)
        ZStack(alignment: .topLeft) {
            Text("aaaa")
            AllocatedHeightEchoView()
        }._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 8, height: 6)))
        // The echo reports 3×1 and paints its ALLOCATED height; it must observe
        // 1, not the 6-row assignment.
        #expect(visibleRows(buffer) == ["H:1a", "", "", "", "", ""])
    }

    @Test func zeroSizedRectPaintsNothing() {
        var buffer = CellBuffer(width: 4, height: 1)
        ZStack { Text("abc") }._embed(into: &buffer, at: .zero)
        #expect(visibleRows(buffer) == [""])
    }

    @Test func childTallerThanTheRectIsClipped() {
        var buffer = CellBuffer(width: 4, height: 2)
        ZStack { ViewOutput("a\nb\nc") }._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 4, height: 2))
        )
        // The raster reports three rows, but the ZStack rect is two rows.
        #expect(visibleRows(buffer) == ["a", "b"])
    }

    @Test func nestedFlexibleChildUsesTheEmbedTimeContext() {
        let stack = ZStack(alignment: .topLeft) {
            Text("b\nc")
            VStack {
                Text("a")
                Spacer()
            }.bg(.red)
        }
        // At measure time the nested VStack is rigid (height nil) and reports
        // 1×1; the text child sets the stack's 1×2 height.
        #expect(
            stack._measure(in: AvailableSize(width: 6, height: nil)) == ViewSize(width: 1, height: 2)
        )
        // At embed time the nested stack is re-queried at the 2-row rect and
        // its flexible spacer fills the second row; its background covers both
        // rows.
        var buffer = CellBuffer(width: 6, height: 2)
        stack._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 6, height: 2)))
        #expect(buffer[0, 0].background == .red)
        #expect(buffer[0, 1].background == .red)
        #expect(visibleRows(buffer) == ["a", "c"])
    }

    @Test func childOverflowIsClippedToItsRect() {
        let buffer = embedBuffer(
            ZStack { ViewOutput("abcd") },
            width: 2
        )
        // The stack reports 4 columns, but the assigned root rect is 2 wide.
        #expect(visibleRows(buffer) == ["ab"])
    }

    @Test func fillClaimsTheAssignedRect() {
        var buffer = CellBuffer(width: 8, height: 3)
        ZStack(alignment: .topLeft) {
            Text("x")
            Fill().bg(.red)
        }._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 8, height: 3)))
        // The styled Fill reports and covers the whole 8×3 assignment.
        #expect(buffer[7, 2].background == .red)
        #expect(visibleRows(buffer) == ["x", "", ""])
    }

    @Test func childObservesItsAllocatedRect() {
        let buffer = embedBuffer(
            ZStack { RectEchoView() },
            width: 20
        )
        // The echo reports 12 wide, so the stack shrink-wraps to 12 and the
        // child observes 12 — not the 20-column root rect.
        #expect(visibleRows(buffer) == ["W:12"])
    }

    @Test func emptyChildrenPaintNothing() {
        let buffer = embedBuffer(
            ZStack {
                Empty()
                Empty()
            },
            width: 8
        )
        #expect(buffer.height == 0)
        #expect(visibleRows(buffer) == [])
    }

    @Test func nestedInVStackParticipatesAsOneChild() {
        let buffer = embedBuffer(
            VStack {
                ZStack(alignment: .topLeft) {
                    Text("ab")
                    Text("c")
                }
                Text("d")
            },
            width: 4
        )
        #expect(visibleRows(buffer) == ["cb", "d"])
    }
}

// MARK: - Test-local query consumers

/// Reports a 1-column width and the queried height; paints nothing.
///
/// Used to prove that the stack forwards the height context to its children.
private struct HeightEchoView: View {
    func _measure(in available: AvailableSize) -> ViewSize {
        ViewSize(width: 1, height: available.height ?? 0)
    }
}

/// Reports 3×1 and paints its allocated height at the rect origin.
///
/// Used to prove that a child smaller than the assignment is not stretched.
private struct AllocatedHeightEchoView: View {
    func _measure(in available: AvailableSize) -> ViewSize {
        ViewSize(width: 3, height: 1)
    }

    func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        buffer.write(
            StyledText("H:\(rect.size.height)"),
            at: rect.origin.col,
            row: rect.origin.row
        )
    }
}
