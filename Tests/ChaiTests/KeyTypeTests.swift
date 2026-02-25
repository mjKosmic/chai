import Testing
import Foundation
@testable import Chai

// MARK: - KeyType Equatable Tests (library-level)

@Suite("KeyType Equatable")
struct KeyTypeEquatableTests {

    @Test func simpleKeyTypesAreEqual() {
        #expect(KeyType.enter == KeyType.enter)
        #expect(KeyType.tab == KeyType.tab)
        #expect(KeyType.escape == KeyType.escape)
        #expect(KeyType.space == KeyType.space)
        #expect(KeyType.backspace == KeyType.backspace)
        #expect(KeyType.delete == KeyType.delete)
        #expect(KeyType.up == KeyType.up)
        #expect(KeyType.down == KeyType.down)
        #expect(KeyType.left == KeyType.left)
        #expect(KeyType.right == KeyType.right)
        #expect(KeyType.runes == KeyType.runes)
        #expect(KeyType.unknown == KeyType.unknown)
    }

    @Test func differentKeyTypesAreNotEqual() {
        #expect(KeyType.enter != KeyType.tab)
        #expect(KeyType.up != KeyType.down)
        #expect(KeyType.left != KeyType.right)
        #expect(KeyType.space != KeyType.enter)
        #expect(KeyType.runes != KeyType.unknown)
    }

    @Test func ctrlKeysWithSameCharAreEqual() {
        #expect(KeyType.ctrl("c") == KeyType.ctrl("c"))
        #expect(KeyType.ctrl("a") == KeyType.ctrl("a"))
        #expect(KeyType.ctrl("z") == KeyType.ctrl("z"))
    }

    @Test func ctrlKeysWithDifferentCharsAreNotEqual() {
        #expect(KeyType.ctrl("c") != KeyType.ctrl("a"))
        #expect(KeyType.ctrl("a") != KeyType.ctrl("z"))
    }

    @Test func functionKeysWithSameNumberAreEqual() {
        #expect(KeyType.f(1) == KeyType.f(1))
        #expect(KeyType.f(12) == KeyType.f(12))
    }

    @Test func functionKeysWithDifferentNumbersAreNotEqual() {
        #expect(KeyType.f(1) != KeyType.f(2))
        #expect(KeyType.f(5) != KeyType.f(12))
    }

    @Test func modifiedNavigationKeysAreEqual() {
        #expect(KeyType.shiftUp == KeyType.shiftUp)
        #expect(KeyType.ctrlLeft == KeyType.ctrlLeft)
        #expect(KeyType.ctrlShiftDown == KeyType.ctrlShiftDown)
    }

    @Test func modifiedNavigationKeysAreNotEqual() {
        #expect(KeyType.shiftUp != KeyType.ctrlUp)
        #expect(KeyType.ctrlLeft != KeyType.ctrlShiftLeft)
        #expect(KeyType.shiftHome != KeyType.ctrlHome)
    }

    @Test func ctrlKeyNotEqualToNonCtrlKey() {
        #expect(KeyType.ctrl("a") != KeyType.runes)
        #expect(KeyType.ctrl("c") != KeyType.enter)
    }

    @Test func functionKeyNotEqualToNonFunctionKey() {
        #expect(KeyType.f(1) != KeyType.runes)
        #expect(KeyType.f(5) != KeyType.enter)
    }
}
