import Testing
@testable import Chai

@Suite("Color")
struct ColorTests {

    // MARK: - Named ANSI values

    @Test func namedValuesCoverEveryANSIColor() {
        let named: [Color] = [
            .black, .red, .green, .yellow, .blue, .magenta, .cyan, .white,
            .brightBlack, .brightRed, .brightGreen, .brightYellow,
            .brightBlue, .brightMagenta, .brightCyan, .brightWhite,
        ]
        #expect(named == ANSIColor.allCases.map { Color.ansi($0) })
    }

    @Test func namedValuesPaintNamedCells() {
        #expect(Color.red.cellColor == .red)
        #expect(Color.cyan.cellColor == .cyan)
        #expect(Color.brightWhite.cellColor == .brightWhite)
    }

    // MARK: - CellColor bridge

    @Test func bridgeFromNamedCellColor() {
        #expect(Color(CellColor.red) == .ansi(.red))
        #expect(Color(CellColor.brightBlue) == .ansi(.brightBlue))
    }

    @Test func bridgeFromPaletteAndRGB() {
        #expect(Color(CellColor.palette(208)) == .extended(208))
        #expect(Color(CellColor.rgb(255, 100, 50)) == .trueColor(r: 255, g: 100, b: 50))
    }

    @Test func bridgeRoundTripsThroughCellColor() {
        let colors: [Color] = [.red, .brightCyan, .extended(42), .trueColor(r: 1, g: 2, b: 3)]
        for color in colors {
            #expect(Color(color.cellColor) == color)
        }
    }
}
