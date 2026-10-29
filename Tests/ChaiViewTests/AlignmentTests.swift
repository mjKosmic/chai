import Testing
import Chai

// MARK: - Combined alignment

@Suite("Alignment")
struct AlignmentTests {

    @Test func defaultIsCenteredOnBothAxes() {
        let alignment = Alignment()
        #expect(alignment.horizontal == .center)
        #expect(alignment.vertical == .middle)
    }

    @Test func topLeftPresetUsesLeftAndTop() {
        #expect(Alignment.topLeft.horizontal == .left)
        #expect(Alignment.topLeft.vertical == .top)
    }

    @Test func topPresetCentersHorizontallyAndPinsToTop() {
        #expect(Alignment.top.horizontal == .center)
        #expect(Alignment.top.vertical == .top)
    }

    @Test func topRightPresetUsesRightAndTop() {
        #expect(Alignment.topRight.horizontal == .right)
        #expect(Alignment.topRight.vertical == .top)
    }

    @Test func leftPresetPinsToLeftAndCentersVertically() {
        #expect(Alignment.left.horizontal == .left)
        #expect(Alignment.left.vertical == .middle)
    }

    @Test func centerPresetUsesCenterAndMiddle() {
        #expect(Alignment.center.horizontal == .center)
        #expect(Alignment.center.vertical == .middle)
    }

    @Test func rightPresetPinsToRightAndCentersVertically() {
        #expect(Alignment.right.horizontal == .right)
        #expect(Alignment.right.vertical == .middle)
    }

    @Test func bottomLeftPresetUsesLeftAndBottom() {
        #expect(Alignment.bottomLeft.horizontal == .left)
        #expect(Alignment.bottomLeft.vertical == .bottom)
    }

    @Test func bottomPresetCentersHorizontallyAndPinsToBottom() {
        #expect(Alignment.bottom.horizontal == .center)
        #expect(Alignment.bottom.vertical == .bottom)
    }

    @Test func bottomRightPresetUsesRightAndBottom() {
        #expect(Alignment.bottomRight.horizontal == .right)
        #expect(Alignment.bottomRight.vertical == .bottom)
    }

    @Test func customFractionsArePreserved() {
        let alignment = Alignment(
            horizontal: HorizontalAlignment(fraction: 0.25),
            vertical: VerticalAlignment(fraction: 0.75)
        )
        #expect(alignment.horizontal.fraction == 0.25)
        #expect(alignment.vertical.fraction == 0.75)
    }

    @Test func oneAxisDefaultsWhenTheOtherIsProvided() {
        let horizontalOnly = Alignment(horizontal: .right)
        #expect(horizontalOnly.horizontal == .right)
        #expect(horizontalOnly.vertical == .middle)

        let verticalOnly = Alignment(vertical: .top)
        #expect(verticalOnly.horizontal == .center)
        #expect(verticalOnly.vertical == .top)
    }

    @Test func defaultEqualsTheCenterPreset() {
        #expect(Alignment() == .center)
    }

    @Test func presetsEqualTheirExplicitComponents() {
        #expect(Alignment.topLeft == Alignment(horizontal: .left, vertical: .top))
        #expect(Alignment.bottomRight == Alignment(horizontal: .right, vertical: .bottom))
    }

    @Test func fractionsAreClamped() {
        let alignment = Alignment(
            horizontal: HorizontalAlignment(fraction: 2),
            vertical: VerticalAlignment(fraction: -1)
        )
        #expect(alignment.horizontal.fraction == 1)
        #expect(alignment.vertical.fraction == 0)
    }
}
