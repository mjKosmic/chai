import Chai
import Latte
// MARK: - Progress messages

/// Internal message for driving the progress bar animation.
struct ProgressFrameMsg: Message {
    let id: Int
    let tag: Int
}

// MARK: - ID generation

private let _progressIDGenerator = IDGenerator()

// MARK: - Progress

/// An animated progress bar with optional percentage display.
///
/// Supports both solid and gradient fills. The animation uses a simple
/// spring-based interpolation for smooth transitions between values.
///
/// ```swift
/// var progress = Progress(width: 40)
///
/// // Set the target (animates smoothly):
/// let cmd = progress.setPercent(0.50)
///
/// // In body:
/// progress.body    // e.g. "████████████████████░░░░░░░░░░░░░░░░░░░░  50%"
/// ```
public struct Progress: View {
    /// The total width of the progress bar in characters.
    public var width: Int

    /// The character used for the filled portion.
    public var fullCharacter: Character

    /// The character used for the empty portion.
    public var emptyCharacter: Character

    /// The color of the filled portion. If a gradient is set, this is the end color.
    public var fullColor: Color?

    /// The color of the empty portion.
    public var emptyColor: Color?

    /// Whether to show the percentage readout.
    public var showPercentage: Bool

    /// Format string for the percentage display. Receives a `Double` 0–100.
    public var percentFormat: String

    /// Style applied to the percentage text.
    public var percentageStyle: Style

    // MARK: - Gradient

    /// If set, the filled bar renders as a gradient from this color to ``fullColor``.
    public var gradientFrom: Color?

    /// If set, the filled bar renders as a multi-stop gradient across these colors.
    ///
    /// Each filled character is colored by interpolating across the provided color
    /// stops from left to right. Supports one or more stops: a single stop is treated
    /// as a solid fill using that color, while two or more stops produce a gradient.
    ///
    /// When `nil` (the default) or when an empty array is provided, the bar uses solid
    /// fill (``fullColor``) or a two-color gradient via ``gradientFrom`` / ``fullColor``.
    ///
    /// **Priority:** `fillGradient` takes precedence over `gradientFrom` when both
    /// are set.
    public var fillGradient: [Color]?

    // MARK: - Spring animation

    /// The spring frequency (affects animation speed). Higher = faster.
    public var springFrequency: Double

    /// The spring damping ratio. 1.0 = critically damped (no overshoot).
    public var springDamping: Double

    // MARK: Private state

    private let _id: Int
    private var _tag: Int
    private var _percent: Double       // currently displayed percent (0.0 – 1.0)
    private var _targetPercent: Double  // target percent to animate toward
    private var _velocity: Double       // spring velocity

    // MARK: - Initializer

    /// Creates a new progress bar.
    ///
    /// - Parameters:
    ///   - width: Bar width in characters. Defaults to 40.
    ///   - fullCharacter: Character for filled section. Defaults to `█`.
    ///   - emptyCharacter: Character for empty section. Defaults to `░`.
    ///   - fullColor: Color for the filled section.
    ///   - emptyColor: Color for the empty section.
    ///   - showPercentage: Whether to show percentage. Defaults to `true`.
    public init(
        width: Int = 40,
        fullCharacter: Character = "█",
        emptyCharacter: Character = "░",
        fullColor: Color? = nil,
        emptyColor: Color? = nil,
        showPercentage: Bool = true
    ) {
        self.width = width
        self.fullCharacter = fullCharacter
        self.emptyCharacter = emptyCharacter
        self.fullColor = fullColor
        self.emptyColor = emptyColor
        self.showPercentage = showPercentage
        self.percentFormat = " %3.0f%%"
        self.percentageStyle = Style()
        self.gradientFrom = nil
        self.fillGradient = nil
        self.springFrequency = 7.0
        self.springDamping = 1.0
        self._id = _progressIDGenerator.next()
        self._tag = 0
        self._percent = 0
        self._targetPercent = 0
        self._velocity = 0
    }

    // MARK: - ELM interface

    /// No initial command needed for progress bars.
    public func initialize() -> Command? { nil }

    /// Handles animation frame messages.
    public mutating func update(_ msg: any Message) -> Command? {
        guard let frame = msg as? ProgressFrameMsg else { return nil }
        guard frame.id == _id, frame.tag == _tag else { return nil }

        // Spring physics step
        let dt = 1.0 / 60.0  // ~60fps frame step
        let omega = 2.0 * .pi * springFrequency
        let dampingForce = 2.0 * springDamping * omega * _velocity
        let springForce = omega * omega * (_targetPercent - _percent)
        let acceleration = springForce - dampingForce

        _velocity += acceleration * dt
        _percent += _velocity * dt

        // Check if settled
        let epsilon = 0.001
        if abs(_percent - _targetPercent) < epsilon && abs(_velocity) < epsilon {
            _percent = _targetPercent
            _velocity = 0
            return nil  // animation complete
        }

        // Clamp display value
        _percent = max(0, min(1, _percent))

        return frameCommand()
    }

    /// Renders the progress bar at the current animated position.
    public var body: ViewOutput {
        ViewOutput(viewAsStyledText(_percent))
    }

    // MARK: - Public API

    /// Sets the target percentage and starts animating toward it.
    ///
    /// - Parameter percent: Target value from 0.0 to 1.0.
    /// - Returns: A command to drive the animation, or `nil` if already at target.
    @discardableResult
    public mutating func setPercent(_ percent: Double) -> Command? {
        let clamped = max(0, min(1, percent))
        _targetPercent = clamped
        _tag += 1

        // If we're already there, no animation needed
        if abs(_percent - _targetPercent) < 0.001 {
            _percent = _targetPercent
            return nil
        }

        return frameCommand()
    }

    /// Increments the target percentage.
    @discardableResult
    public mutating func incrementPercent(_ delta: Double) -> Command? {
        setPercent(_targetPercent + delta)
    }

    /// Decrements the target percentage.
    @discardableResult
    public mutating func decrementPercent(_ delta: Double) -> Command? {
        setPercent(_targetPercent - delta)
    }

    /// Sets the displayed percentage immediately without animation.
    public mutating func setPercentImmediate(_ percent: Double) {
        let clamped = max(0, min(1, percent))
        _percent = clamped
        _targetPercent = clamped
        _velocity = 0
        _tag += 1
    }

    /// The current displayed percentage (may be mid-animation).
    public var percent: Double { _percent }

    /// The target percentage being animated toward.
    public var targetPercent: Double { _targetPercent }

    // MARK: - StyledText rendering

    /// Renders the progress bar at an arbitrary percentage (no animation) as structured styled text.
    ///
    /// Returns ``StyledText`` so the cell-buffer renderer receives
    /// ``TextAttributes`` metadata rather than raw ANSI escape bytes.
    ///
    /// - Parameter percent: A value from 0.0 to 1.0.
    /// - Returns: The rendered progress bar as ``StyledText``.
    public func viewAsStyledText(_ percent: Double) -> StyledText {
        let clamped = max(0, min(1, percent))
        let filledWidth = Int(Double(width) * clamped)
        let emptyWidth = width - filledWidth

        var bar = StyledText()

        // Build filled portion
        if let stops = fillGradient, !stops.isEmpty {
            bar += renderMultiStopGradientStyled(colors: stops, width: filledWidth)
        } else if let gradFrom = gradientFrom, let gradTo = fullColor {
            bar += renderGradientStyled(from: gradFrom, to: gradTo, width: filledWidth)
        } else {
            let filled = String(repeating: fullCharacter, count: filledWidth)
            if let color = fullColor {
                bar += Style(foreground: color).styledText(filled)
            } else {
                bar += StyledText(filled)
            }
        }

        // Build empty portion
        let empty = String(repeating: emptyCharacter, count: emptyWidth)
        if let color = emptyColor {
            bar += Style(foreground: color).styledText(empty)
        } else {
            bar += StyledText(empty)
        }

        // Percentage readout
        if showPercentage {
            let pct = String(format: percentFormat, clamped * 100)
            bar += percentageStyle.styledText(pct)
        }

        return bar
    }

    /// StyledText equivalent of ``renderMultiStopGradient(colors:width:)``.
    private func renderMultiStopGradientStyled(colors: [Color], width: Int) -> StyledText {
        guard width > 0 else { return StyledText() }
        guard colors.count >= 2 else {
            let filled = String(repeating: fullCharacter, count: width)
            if let color = colors.first {
                return Style(foreground: color).styledText(filled)
            }
            return StyledText(filled)
        }

        var result = StyledText()
        for i in 0..<width {
            let t = width > 1 ? Double(i) / Double(width - 1) : 1.0
            let scaled = t * Double(colors.count - 1)
            let segIdx = min(Int(scaled), colors.count - 2)
            let segT = scaled - Double(segIdx)
            let color = blend(colors[segIdx], colors[segIdx + 1], t: segT)
            result += Style(foreground: color).styledText(String(fullCharacter))
        }
        return result
    }

    /// StyledText equivalent of ``renderGradient(from:to:width:)``.
    private func renderGradientStyled(from: Color, to: Color, width: Int) -> StyledText {
        guard width > 0 else { return StyledText() }
        guard case let .trueColor(r1, g1, b1) = from,
              case let .trueColor(r2, g2, b2) = to else {
            let filled = String(repeating: fullCharacter, count: width)
            return Style(foreground: to).styledText(filled)
        }

        var result = StyledText()
        for i in 0..<width {
            let t = width > 1 ? Double(i) / Double(width - 1) : 1.0
            let r = UInt8(Double(r1) + (Double(r2) - Double(r1)) * t)
            let g = UInt8(Double(g1) + (Double(g2) - Double(g1)) * t)
            let b = UInt8(Double(b1) + (Double(b2) - Double(b1)) * t)
            result += Style(foreground: .trueColor(r: r, g: g, b: b))
                .styledText(String(fullCharacter))
        }
        return result
    }

    // MARK: - Private

    private func frameCommand() -> Command? {
        let id = self._id
        let tag = self._tag
        return .tick(.milliseconds(16)) { _ in
            ProgressFrameMsg(id: id, tag: tag)
        }
    }
}
