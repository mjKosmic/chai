/// Extracts the first line of a string block, discarding all subsequent lines.
///
/// Use `inline` when you need to collapse a multi-line layout result into a
/// single line — for example, to embed a bordered label inside a status bar
/// or to extract a title from a composed block.
///
/// No other transformation is applied: the first line is returned exactly as-is,
/// including any ANSI escape sequences it contains.
///
/// ```swift
/// inline("Hello\nWorld")
/// // "Hello"
///
/// inline("Only one line")
/// // "Only one line"
///
/// inline("")
/// // ""
/// ```
///
/// - Parameter text: The string to extract the first line from.
///   May contain `\n`-separated lines.
/// - Returns: The first line of `text`.
public func inline(_ text: String) -> String {
    guard let newlineIndex = text.firstIndex(of: "\n") else {
        return text
    }
    return String(text[text.startIndex..<newlineIndex])
}
