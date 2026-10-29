import Testing
@testable import Chai

// MARK: - Milestone 6.1: HSL Color Math Helpers

@Suite("ColorUtilities")
struct ColorUtilitiesTests {

    // MARK: - darken

    @Test func darkenReducesLightness() {
        // A mid-tone gray in truecolor: r=128, g=128, b=128 has l≈0.5
        let gray = Color.trueColor(r: 128, g: 128, b: 128)
        let darker = darken(gray, 0.2)
        // Result is .trueColor and should have lower RGB values (darker)
        if case let .trueColor(r, g, b) = darker {
            #expect(Int(r) < 128)
            #expect(Int(g) < 128)
            #expect(Int(b) < 128)
        } else {
            #expect(Bool(false), "darken should return .trueColor")
        }
    }

    @Test func darkenByZeroIsIdentity() {
        let color = Color.trueColor(r: 100, g: 150, b: 200)
        let result = darken(color, 0.0)
        if case let .trueColor(r, g, b) = result {
            // Should be very close to the original (rounding may differ by ≤1)
            #expect(abs(Int(r) - 100) <= 1)
            #expect(abs(Int(g) - 150) <= 1)
            #expect(abs(Int(b) - 200) <= 1)
        } else {
            #expect(Bool(false), "darken should return .trueColor")
        }
    }

    @Test func darkenByOneProducesBlack() {
        let color = Color.trueColor(r: 200, g: 100, b: 50)
        let result = darken(color, 1.0)
        if case let .trueColor(r, g, b) = result {
            #expect(r == 0)
            #expect(g == 0)
            #expect(b == 0)
        } else {
            #expect(Bool(false), "darken should return .trueColor")
        }
    }

    @Test func darkenWorksOnAnsiColor() {
        // ANSI color should be converted internally and return .trueColor
        let result = darken(.ansi(.red), 0.1)
        if case .trueColor = result {
            // Good
        } else {
            #expect(Bool(false), "darken of .ansi should return .trueColor")
        }
    }

    @Test func darkenWorksOnExtendedColor() {
        let result = darken(.extended(196), 0.1)
        if case .trueColor = result {
            // Good
        } else {
            #expect(Bool(false), "darken of .extended should return .trueColor")
        }
    }

    // MARK: - lighten

    @Test func lightenIncreasesLightness() {
        let gray = Color.trueColor(r: 100, g: 100, b: 100)
        let lighter = lighten(gray, 0.2)
        if case let .trueColor(r, g, b) = lighter {
            #expect(Int(r) > 100)
            #expect(Int(g) > 100)
            #expect(Int(b) > 100)
        } else {
            #expect(Bool(false), "lighten should return .trueColor")
        }
    }

    @Test func lightenByOneProducesWhite() {
        let color = Color.trueColor(r: 50, g: 100, b: 150)
        let result = lighten(color, 1.0)
        if case let .trueColor(r, g, b) = result {
            #expect(r == 255)
            #expect(g == 255)
            #expect(b == 255)
        } else {
            #expect(Bool(false), "lighten should return .trueColor")
        }
    }

    @Test func lightenByZeroIsIdentity() {
        let color = Color.trueColor(r: 80, g: 120, b: 200)
        let result = lighten(color, 0.0)
        if case let .trueColor(r, g, b) = result {
            #expect(abs(Int(r) - 80) <= 1)
            #expect(abs(Int(g) - 120) <= 1)
            #expect(abs(Int(b) - 200) <= 1)
        } else {
            #expect(Bool(false), "lighten should return .trueColor")
        }
    }

    @Test func lightenWorksOnAnsiColor() {
        let result = lighten(.ansi(.blue), 0.2)
        if case .trueColor = result {
            // Good
        } else {
            #expect(Bool(false), "lighten of .ansi should return .trueColor")
        }
    }

    // MARK: - complementary

    @Test func complementaryRotatesHue180() {
        // Pure red (hue ≈ 0°) should become cyan (hue ≈ 180°)
        let red  = Color.trueColor(r: 255, g: 0, b: 0)
        let comp = complementary(red)
        if case let .trueColor(r, g, b) = comp {
            // Cyan has very low red and roughly equal high green/blue
            #expect(Int(r) < 50)
            #expect(Int(g) > 200)
            #expect(Int(b) > 200)
        } else {
            #expect(Bool(false), "complementary should return .trueColor")
        }
    }

    @Test func complementaryOfComplementaryIsApproximatelyOriginal() {
        let color = Color.trueColor(r: 200, g: 80, b: 40)
        let comp  = complementary(color)
        let back  = complementary(comp)
        // Due to rounding, allow a small delta
        guard case let .trueColor(r1, g1, b1) = color,
              case let .trueColor(r2, g2, b2) = back else {
            #expect(Bool(false))
            return
        }
        #expect(abs(Int(r1) - Int(r2)) <= 3)
        #expect(abs(Int(g1) - Int(g2)) <= 3)
        #expect(abs(Int(b1) - Int(b2)) <= 3)
    }

    @Test func complementaryWorksOnAnsiColor() {
        let result = complementary(.ansi(.cyan))
        if case .trueColor = result {
            // Good
        } else {
            #expect(Bool(false), "complementary of .ansi should return .trueColor")
        }
    }

    // MARK: - blend

    @Test func blendAtZeroReturnsFrom() {
        let from = Color.trueColor(r: 255, g: 0, b: 0)
        let to   = Color.trueColor(r: 0, g: 0, b: 255)
        let result = blend(from, to, t: 0.0)
        if case let .trueColor(r, g, b) = result {
            #expect(r == 255)
            #expect(g == 0)
            #expect(b == 0)
        } else {
            #expect(Bool(false), "blend should return .trueColor")
        }
    }

    @Test func blendAtOneReturnsTo() {
        let from = Color.trueColor(r: 255, g: 0, b: 0)
        let to   = Color.trueColor(r: 0, g: 0, b: 255)
        let result = blend(from, to, t: 1.0)
        if case let .trueColor(r, g, b) = result {
            #expect(r == 0)
            #expect(g == 0)
            #expect(b == 255)
        } else {
            #expect(Bool(false), "blend should return .trueColor")
        }
    }

    @Test func blendAtHalfProducesMidpoint() {
        let from = Color.trueColor(r: 0,   g: 0,   b: 0)
        let to   = Color.trueColor(r: 200, g: 100, b: 50)
        let result = blend(from, to, t: 0.5)
        if case let .trueColor(r, g, b) = result {
            #expect(abs(Int(r) - 100) <= 1)
            #expect(abs(Int(g) - 50)  <= 1)
            #expect(abs(Int(b) - 25)  <= 1)
        } else {
            #expect(Bool(false), "blend should return .trueColor")
        }
    }

    @Test func blendClampsNegativeT() {
        let from = Color.trueColor(r: 100, g: 50, b: 200)
        let to   = Color.trueColor(r: 0,   g: 0,  b: 0)
        let result = blend(from, to, t: -0.5)
        // Negative t is clamped to 0, so result should equal 'from'
        if case let .trueColor(r, g, b) = result {
            #expect(r == 100)
            #expect(g == 50)
            #expect(b == 200)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func blendClampsAboveOneT() {
        let from = Color.trueColor(r: 0, g: 0, b: 0)
        let to   = Color.trueColor(r: 255, g: 128, b: 64)
        let result = blend(from, to, t: 2.0)
        if case let .trueColor(r, g, b) = result {
            #expect(r == 255)
            #expect(g == 128)
            #expect(b == 64)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func blendWorksOnAnsiColors() {
        // .ansi(.red) and .ansi(.blue) should be converted internally
        let result = blend(.ansi(.red), .ansi(.blue), t: 0.5)
        if case .trueColor = result {
            // Good
        } else {
            #expect(Bool(false), "blend of .ansi should return .trueColor")
        }
    }

    // MARK: - gradient (1D)

    @Test func gradientZeroStepsIsEmpty() {
        let result = gradient(from: .ansi(.red), to: .ansi(.blue), steps: 0)
        #expect(result.isEmpty)
    }

    @Test func gradientOneStepReturnsStart() {
        let start = Color.trueColor(r: 255, g: 0, b: 0)
        let end   = Color.trueColor(r: 0,   g: 0, b: 255)
        let result = gradient(from: start, to: end, steps: 1)
        #expect(result.count == 1)
        if case let .trueColor(r, g, b) = result[0] {
            #expect(r == 255)
            #expect(g == 0)
            #expect(b == 0)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func gradientTwoStepsReturnsStartAndEnd() {
        let start = Color.trueColor(r: 255, g: 0, b: 0)
        let end   = Color.trueColor(r: 0,   g: 0, b: 255)
        let result = gradient(from: start, to: end, steps: 2)
        #expect(result.count == 2)
        // First should equal start
        if case let .trueColor(r, _, _) = result[0] { #expect(r == 255) }
        // Last should equal end
        if case let .trueColor(_, _, b) = result[1] { #expect(b == 255) }
    }

    @Test func gradientFiveStepsHasFiveElements() {
        let result = gradient(from: .ansi(.red), to: .ansi(.blue), steps: 5)
        #expect(result.count == 5)
    }

    @Test func gradientAllResultsAreTrueColor() {
        let result = gradient(from: .ansi(.red), to: .ansi(.blue), steps: 5)
        for color in result {
            if case .trueColor = color {
                // Good
            } else {
                #expect(Bool(false), "All gradient results should be .trueColor")
            }
        }
    }

    @Test func gradientProgressesFromStartToEnd() {
        // Red (255,0,0) → Blue (0,0,255): red component should decrease,
        // blue component should increase.
        let result = gradient(
            from: .ansi(.brightRed),  // (255,0,0)
            to:   .ansi(.brightBlue), // (0,0,255)
            steps: 5
        )
        var prevR = Int.max
        var prevB = -1
        for color in result {
            if case let .trueColor(r, _, b) = color {
                #expect(Int(r) <= prevR)
                #expect(Int(b) >= prevB)
                prevR = Int(r)
                prevB = Int(b)
            }
        }
    }

    @Test func gradientExtendedColorsConvertedToTrueColor() {
        let result = gradient(from: .extended(9), to: .extended(12), steps: 3)
        for color in result {
            if case .trueColor = color { /* good */ }
            else { #expect(Bool(false)) }
        }
    }
}

// MARK: - Milestone 6.2: 2D Gradient

@Suite("Gradient2D")
struct Gradient2DTests {

    @Test func emptyWidthReturnsEmptyArray() {
        let result = gradient2D(
            width: 0, height: 3,
            topLeft: .ansi(.red), topRight: .ansi(.blue),
            bottomLeft: .ansi(.green), bottomRight: .ansi(.yellow)
        )
        #expect(result.isEmpty)
    }

    @Test func emptyHeightReturnsEmptyArray() {
        let result = gradient2D(
            width: 3, height: 0,
            topLeft: .ansi(.red), topRight: .ansi(.blue),
            bottomLeft: .ansi(.green), bottomRight: .ansi(.yellow)
        )
        #expect(result.isEmpty)
    }

    @Test func oneByOneGridReturnsTopLeftColor() {
        let result = gradient2D(
            width: 1, height: 1,
            topLeft:     .trueColor(r: 200, g: 0, b: 0),
            topRight:    .trueColor(r: 0, g: 200, b: 0),
            bottomLeft:  .trueColor(r: 0, g: 0, b: 200),
            bottomRight: .trueColor(r: 200, g: 200, b: 0)
        )
        #expect(result.count == 1)
        #expect(result[0].count == 1)
        // With 1×1 grid, t = 0 in both dimensions → topLeft color
        if case let .trueColor(r, _, _) = result[0][0] {
            #expect(r == 200)
        }
    }

    @Test func correctDimensions() {
        let result = gradient2D(
            width: 4, height: 3,
            topLeft: .ansi(.red), topRight: .ansi(.blue),
            bottomLeft: .ansi(.green), bottomRight: .ansi(.yellow)
        )
        #expect(result.count == 3)     // height rows
        #expect(result[0].count == 4)  // width cols per row
        #expect(result[1].count == 4)
        #expect(result[2].count == 4)
    }

    @Test func allResultsAreTrueColor() {
        let result = gradient2D(
            width: 3, height: 3,
            topLeft: .ansi(.red), topRight: .ansi(.blue),
            bottomLeft: .ansi(.green), bottomRight: .ansi(.yellow)
        )
        for row in result {
            for color in row {
                if case .trueColor = color { /* good */ }
                else { #expect(Bool(false), "All gradient2D results should be .trueColor") }
            }
        }
    }

    @Test func topRowMatchesHorizontalGradient() {
        // The top row should match a 1D gradient from topLeft to topRight
        let topLeft     = Color.trueColor(r: 255, g: 0, b: 0)
        let topRight    = Color.trueColor(r: 0,   g: 0, b: 255)
        let bottomLeft  = Color.trueColor(r: 0,   g: 255, b: 0)
        let bottomRight = Color.trueColor(r: 255, g: 255, b: 0)

        let grid  = gradient2D(width: 4, height: 3,
                               topLeft: topLeft, topRight: topRight,
                               bottomLeft: bottomLeft, bottomRight: bottomRight)
        let hgrad = gradient(from: topLeft, to: topRight, steps: 4)

        for col in 0..<4 {
            guard case let .trueColor(gr, gg, gb) = grid[0][col],
                  case let .trueColor(hr, hg, hb) = hgrad[col] else {
                #expect(Bool(false)); continue
            }
            #expect(abs(Int(gr) - Int(hr)) <= 1)
            #expect(abs(Int(gg) - Int(hg)) <= 1)
            #expect(abs(Int(gb) - Int(hb)) <= 1)
        }
    }

    @Test func leftColumnMatchesVerticalGradient() {
        let topLeft     = Color.trueColor(r: 255, g: 0, b: 0)
        let topRight    = Color.trueColor(r: 0,   g: 0, b: 255)
        let bottomLeft  = Color.trueColor(r: 0,   g: 0, b: 200)
        let bottomRight = Color.trueColor(r: 200, g: 200, b: 0)

        let grid  = gradient2D(width: 3, height: 4,
                               topLeft: topLeft, topRight: topRight,
                               bottomLeft: bottomLeft, bottomRight: bottomRight)
        let vgrad = gradient(from: topLeft, to: bottomLeft, steps: 4)

        for row in 0..<4 {
            guard case let .trueColor(gr, gg, gb) = grid[row][0],
                  case let .trueColor(vr, vg, vb) = vgrad[row] else {
                #expect(Bool(false)); continue
            }
            #expect(abs(Int(gr) - Int(vr)) <= 1)
            #expect(abs(Int(gg) - Int(vg)) <= 1)
            #expect(abs(Int(gb) - Int(vb)) <= 1)
        }
    }
}
