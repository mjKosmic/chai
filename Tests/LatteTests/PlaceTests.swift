import Testing
@testable import Latte

@Suite("Place")
struct PlaceTests {

    // MARK: - placeHorizontal

    @Test func placeHorizontalLeftAlignment() {
        let result = placeHorizontal(width: 10, .left, "Hi")
        #expect(result == "Hi        ")
        #expect(visibleWidth(of: result) == 10)
    }

    @Test func placeHorizontalRightAlignment() {
        let result = placeHorizontal(width: 10, .right, "Hi")
        #expect(result == "        Hi")
        #expect(visibleWidth(of: result) == 10)
    }

    @Test func placeHorizontalCenterAlignment() {
        // "Hi" in 10 → shortage 8 → 4 left, 4 right
        let result = placeHorizontal(width: 10, .center, "Hi")
        #expect(result == "    Hi    ")
        #expect(visibleWidth(of: result) == 10)
    }

    @Test func placeHorizontalExactWidthIsUnchanged() {
        #expect(placeHorizontal(width: 5, .left, "Hello") == "Hello")
    }

    @Test func placeHorizontalMultiLine() {
        let result = placeHorizontal(width: 8, .center, "Hi\nBye")
        let lines = result.components(separatedBy: "\n")
        // "Hi"  in 8 → 3 left, 3 right
        // "Bye" in 8 → 2 left (8-3=5, 5/2=2), 3 right... wait shortage=5, leftPad=2, rightPad=3
        #expect(lines[0] == "   Hi   ")
        #expect(lines[1] == "  Bye   ")
        for line in lines {
            #expect(visibleWidth(of: line) == 8)
        }
    }

    @Test func placeHorizontalWiderThanWidthIsUnchanged() {
        let result = placeHorizontal(width: 3, .center, "Hello!")
        #expect(result == "Hello!")
    }

    // MARK: - placeVertical

    @Test func placeVerticalTopAlignment() {
        let result = placeVertical(height: 4, .top, "A\nB")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == "A")
        #expect(lines[1] == "B")
        // Blank lines at bottom
        #expect(lines[2] == " ")
        #expect(lines[3] == " ")
    }

    @Test func placeVerticalBottomAlignment() {
        let result = placeVertical(height: 4, .bottom, "A\nB")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == " ")
        #expect(lines[1] == " ")
        #expect(lines[2] == "A")
        #expect(lines[3] == "B")
    }

    @Test func placeVerticalMiddleAlignment() {
        // 2 lines into 4 → shortage 2 → 1 top, 1 bottom
        let result = placeVertical(height: 4, .middle, "A\nB")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == " ")
        #expect(lines[1] == "A")
        #expect(lines[2] == "B")
        #expect(lines[3] == " ")
    }

    @Test func placeVerticalAlreadyTallEnoughIsUnchanged() {
        let text = "A\nB\nC\nD"
        #expect(placeVertical(height: 2, .top, text) == text)
    }

    // MARK: - place (combined)

    @Test func placeTopLeft() {
        let result = place(width: 10, height: 4, horizontal: .left, vertical: .top, "Hi")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == "Hi        ")
        // All blank lines should be 10 wide
        for line in lines {
            #expect(visibleWidth(of: line) == 10)
        }
    }

    @Test func placeCenter() {
        // "Hi" centred in 10×5
        let result = place(width: 10, height: 5, horizontal: .center, vertical: .middle, "Hi")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 5)
        // Content should be on middle line(s):
        // 1 line into 5 → shortage 4 → topPad = 2, bottomPad = 2
        #expect(lines[0] == "          ")   // blank, 10 cols
        #expect(lines[1] == "          ")   // blank, 10 cols
        #expect(lines[2] == "    Hi    ")   // centered "Hi" in 10
        #expect(lines[3] == "          ")   // blank
        #expect(lines[4] == "          ")   // blank
    }

    @Test func placeBottomRight() {
        let result = place(width: 8, height: 3, horizontal: .right, vertical: .bottom, "Hi")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[2] == "      Hi")
        for line in lines {
            #expect(visibleWidth(of: line) == 8)
        }
    }

    // MARK: - Composition with other Latte functions

    @Test func placeWorksWithBorderedContent() {
        let box = border("Hi", .rounded)
        let result = place(width: 14, height: 5, horizontal: .center, vertical: .middle, box)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 5)
        // Box is 4 cols wide (╭──╮) and 3 lines tall
        // Centre horizontally in 14: (14-4)/2 = 5 leading spaces
        // Centre vertically in 5: shortage=2 → 1 top, 1 bottom
        #expect(lines[0].count >= 14 || visibleWidth(of: lines[0]) == 14)
        #expect(lines[1].contains("╭"))
        #expect(lines[2].contains("│"))
        #expect(lines[3].contains("╰"))
    }
}
