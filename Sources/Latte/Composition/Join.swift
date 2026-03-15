/// Functions for joining multiple string blocks side-by-side or stacked.

// MARK: - joinHorizontal

/// Joins two or more string blocks side by side.
///
/// Blocks are placed left-to-right with no separator. When blocks have
/// different heights, shorter blocks are padded with blank lines according to
/// `alignment`:
/// - `.top` — shorter blocks are padded at the bottom.
/// - `.middle` — shorter blocks are padded evenly above and below.
/// - `.bottom` — shorter blocks are padded at the top.
///
/// Every line in each block is first padded to that block's maximum width,
/// producing a uniform column before concatenation.
///
/// ```swift
/// let left  = "Hello\nWorld"  // 5 cols, 2 lines
/// let right = "!"             // 1 col,  1 line
///
/// joinHorizontal(.top, left, right)
/// // "Hello!"
/// // "World "
///
/// joinHorizontal(.bottom, left, right)
/// // "Hello "
/// // "World!"
/// ```
///
/// - Parameters:
///   - alignment: How shorter blocks are vertically aligned within the tallest.
///   - blocks: Two or more string blocks to join. Single-block calls return
///     the block unchanged.
/// - Returns: The joined string, with rows separated by `\n`.
public func joinHorizontal(_ alignment: VerticalAlignment, _ blocks: String...) -> String {
    joinHorizontal(alignment, blocks)
}

/// Array overload of ``joinHorizontal(_:_:)-5h7fk``.
///
/// Useful when the blocks are in a dynamic collection.
public func joinHorizontal(_ alignment: VerticalAlignment, _ blocks: [String]) -> String {
    guard !blocks.isEmpty else { return "" }
    guard blocks.count > 1 else { return blocks[0] }

    let splitBlocks = blocks.map { splitLines($0) }
    let maxHeight = splitBlocks.map { $0.count }.max() ?? 0

    // For each block: determine its column width, pad lines to that width,
    // then extend to maxHeight by inserting blank lines per alignment.
    let paddedBlocks: [[String]] = splitBlocks.map { lines in
        let blockWidth = lines.map { visibleWidth(of: $0) }.max() ?? 0
        let blankLine = String(repeating: " ", count: blockWidth)

        // Uniform-width lines
        let uniformLines = lines.map { padLineRight($0, toWidth: blockWidth) }

        // Height padding
        let shortage = maxHeight - uniformLines.count
        guard shortage > 0 else { return uniformLines }

        let topPad = Int(Double(shortage) * alignment.fraction)
        let bottomPad = shortage - topPad
        return Array(repeating: blankLine, count: topPad)
            + uniformLines
            + Array(repeating: blankLine, count: bottomPad)
    }

    // Zip rows across all blocks.
    return (0..<maxHeight)
        .map { row in paddedBlocks.map { $0[row] }.joined() }
        .joined(separator: "\n")
}

// MARK: - joinVertical

/// Stacks two or more string blocks vertically.
///
/// Blocks are placed top-to-bottom with no separator. When blocks have
/// different widths, narrower blocks are padded with spaces according to
/// `alignment`:
/// - `.left` — narrower blocks are padded on the right.
/// - `.center` — narrower blocks are padded evenly on both sides.
/// - `.right` — narrower blocks are padded on the left.
///
/// ```swift
/// let top    = "Hello, World!"  // 13 cols
/// let bottom = "Hi"             //  2 cols
///
/// joinVertical(.center, top, bottom)
/// // "Hello, World!"
/// // "     Hi      "
/// ```
///
/// - Parameters:
///   - alignment: How narrower blocks are horizontally aligned within the widest.
///   - blocks: Two or more string blocks to stack. Single-block calls return
///     the block unchanged.
/// - Returns: The stacked string, with rows separated by `\n`.
public func joinVertical(_ alignment: HorizontalAlignment, _ blocks: String...) -> String {
    joinVertical(alignment, blocks)
}

/// Array overload of ``joinVertical(_:_:)-3zco8``.
///
/// Useful when the blocks are in a dynamic collection.
public func joinVertical(_ alignment: HorizontalAlignment, _ blocks: [String]) -> String {
    guard !blocks.isEmpty else { return "" }
    guard blocks.count > 1 else { return blocks[0] }

    let allLines = blocks.flatMap { splitLines($0) }
    let maxWidth = allLines.map { visibleWidth(of: $0) }.max() ?? 0

    return allLines
        .map { alignLine($0, width: maxWidth, alignment) }
        .joined(separator: "\n")
}
