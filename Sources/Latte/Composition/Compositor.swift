// MARK: - Layer

/// A positioned content layer for use with ``Compositor``.
///
/// A `Layer` wraps a multi-line string block and gives it a position
/// (`x`, `y`) in the compositor's coordinate system and a `z` depth that
/// controls draw order.
///
/// ```swift
/// Layer(content: "Hello", x: 5, y: 2, z: 1)
/// ```
public struct Layer: Sendable {
    /// The multi-line string block rendered by this layer.
    public var content: String

    /// Column offset from the left edge of the compositor canvas (0-based).
    public var x: Int

    /// Row offset from the top of the compositor canvas (0-based).
    public var y: Int

    /// Z-index. Higher values are rendered on top of lower values.
    public var z: Int

    /// Creates a new layer.
    ///
    /// - Parameters:
    ///   - content: A multi-line string block (lines separated by `\n`).
    ///   - x: Column offset from the left edge of the canvas (0-based).
    ///   - y: Row offset from the top of the canvas (0-based).
    ///   - z: Z-index. Defaults to `0`.
    public init(content: String, x: Int, y: Int, z: Int = 0) {
        self.content = content
        self.x = x
        self.y = y
        self.z = z
    }
}

// MARK: - Compositor

/// A cell-based compositor that renders multiple ``Layer`` values onto a
/// fixed-size `width × height` canvas.
///
/// Layers are sorted by ascending `z` before rendering (lower z rendered
/// first, higher z on top). **Space characters in a higher-z layer are
/// transparent** — they do not overwrite content written by lower layers.
/// All content outside the compositor's bounds is clipped.
///
/// ANSI escape sequences embedded in layer content are preserved correctly;
/// they are tracked during parsing and associated with the visible character
/// that follows them.
///
/// ```swift
/// var comp = Compositor(width: 30, height: 5)
///
/// // Background panel
/// comp.add(Layer(content: border("Hello world", .rounded), x: 0, y: 0, z: 0))
///
/// // Floating overlay (spaces show through to background)
/// comp.add(Layer(content: "[ OK ]", x: 12, y: 2, z: 1))
///
/// print(comp.render())
/// ```
public struct Compositor: Sendable {
    /// The width of the compositing canvas in columns.
    public var width: Int

    /// The height of the compositing canvas in rows.
    public var height: Int

    private var _layers: [Layer]

    // MARK: - Initializer

    /// Creates a new compositor with the given canvas dimensions.
    ///
    /// - Parameters:
    ///   - width: Canvas width in columns.
    ///   - height: Canvas height in rows.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self._layers = []
    }

    // MARK: - Layer management

    /// Adds a layer to the compositor.
    ///
    /// Layers can be added in any order; they are sorted by `z` at render time.
    public mutating func add(_ layer: Layer) {
        _layers.append(layer)
    }

    // MARK: - Rendering

    /// Composites all layers and returns the rendered string.
    ///
    /// Processing order:
    /// 1. Layers are sorted by ascending `z` (lowest first).
    /// 2. Each layer's content is parsed into characters, tracking ANSI state.
    /// 3. Non-space characters always overwrite lower-z content.
    /// 4. Space characters are transparent — they do not overwrite existing cells.
    /// 5. Content outside `width × height` is silently clipped.
    ///
    /// - Returns: A multi-line string with `height` rows separated by `\n`.
    ///   Each row is exactly `width` visible columns wide.
    public func render() -> String {
        guard width > 0, height > 0 else { return "" }

        // Each cell stores the styled string fragment to emit, or nil (= unset / render as space).
        // An empty string "" marks the continuation column of a double-wide character.
        var grid: [[String?]] = Array(
            repeating: Array(repeating: nil, count: width),
            count: height
        )

        // Sort ascending: lowest z drawn first, highest z drawn last (on top).
        let sorted = _layers.sorted { $0.z < $1.z }

        for layer in sorted {
            compositeLayer(layer, into: &grid)
        }

        return renderGrid(grid)
    }

    // MARK: - Private: layer compositing

    private func compositeLayer(_ layer: Layer, into grid: inout [[String?]]) {
        let lines = layer.content.components(separatedBy: "\n")

        for (lineIdx, line) in lines.enumerated() {
            let row = layer.y + lineIdx
            guard row >= 0, row < height else { continue }

            var col = layer.x
            var pendingANSI = ""
            var i = line.startIndex

            while i < line.endIndex {
                let char = line[i]

                // Accumulate ANSI/escape sequences; associate them with the next visible char.
                if char.unicodeScalars.first == TerminalScalar.escape {
                    let end = skipANSISequence(in: line, from: i)
                    pendingANSI += line[i..<end]
                    i = end
                    continue
                }

                let charWidth = displayWidth(of: char)

                if col >= 0 && col < width {
                    let cellContent = pendingANSI + String(char)
                    pendingANSI = ""

                    // Transparency rule: a space in a higher-z layer does not overwrite
                    // existing content from a lower layer.
                    if char == " " && grid[row][col] != nil {
                        // transparent — leave the lower-layer cell intact
                    } else {
                        grid[row][col] = cellContent
                        // Double-wide characters occupy two columns; mark the continuation
                        // column with "" so nothing extra is emitted for it.
                        if charWidth == 2 && col + 1 < width {
                            grid[row][col + 1] = ""
                        }
                    }
                } else {
                    // Out-of-bounds column: discard pending ANSI (nothing to attach it to).
                    pendingANSI = ""
                }

                col += max(1, charWidth)
                i = line.index(after: i)
            }
        }
    }

    // MARK: - Private: grid rendering

    private func renderGrid(_ grid: [[String?]]) -> String {
        var rows: [String] = []
        rows.reserveCapacity(height)

        for row in grid {
            var line = ""
            var needsReset = false

            for cell in row {
                // Emit a SGR reset before the next cell if the previous one contained ANSI codes.
                // This prevents colour/style state from leaking into neighbouring cells.
                if needsReset {
                    line += "\u{1B}[m"
                    needsReset = false
                }

                if let content = cell {
                    line += content
                    // If this fragment carries ANSI sequences, we must reset after it
                    // (before the next cell) to avoid bleeding into adjacent cells.
                    if content.unicodeScalars.contains(TerminalScalar.escape) {
                        needsReset = true
                    }
                } else {
                    // Unset cell: render as a plain space.
                    line += " "
                }
            }

            // Close any open ANSI state at the end of the row.
            if needsReset {
                line += "\u{1B}[m"
            }

            rows.append(line)
        }

        return rows.joined(separator: "\n")
    }
}
