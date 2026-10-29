import Chai
import Foundation

// MARK: - File Entry

/// Metadata about a file or directory entry.
public struct FileEntry: Sendable {
    /// The file or directory name.
    public let name: String
    /// Whether this entry is a directory.
    public let isDirectory: Bool
    /// Whether this entry is a symbolic link.
    public let isSymlink: Bool
    /// The file size in bytes (0 for directories).
    public let size: UInt64
    /// The POSIX permission string (e.g. "rwxr-xr-x").
    public let permissions: String
    /// Whether the file is hidden (name starts with ".").
    public var isHidden: Bool { name.hasPrefix(".") }
}

// MARK: - FilePicker messages

/// Internal message delivered after a directory read completes.
struct FilePickerReadDirMsg: Message {
    let id: Int
    let entries: [FileEntry]
    let directory: String
}

/// Internal message for directory read errors.
struct FilePickerErrorMsg: Message {
    let id: Int
    let error: String
}

// MARK: - FilePicker Styles

/// Styles for the file picker component.
public struct FilePickerStyles: Sendable {
    /// Style for the cursor indicator.
    public var cursor: Style
    /// Style for disabled cursor.
    public var disabledCursor: Style
    /// Style for symbolic links.
    public var symlink: Style
    /// Style for directories.
    public var directory: Style
    /// Style for regular files.
    public var file: Style
    /// Style for disabled (non-selectable) files.
    public var disabledFile: Style
    /// Style for permission strings.
    public var permission: Style
    /// Style for the selected item.
    public var selected: Style
    /// Style for disabled selected items.
    public var disabledSelected: Style
    /// Style for file sizes.
    public var fileSize: Style
    /// Style for the empty directory message.
    public var emptyDirectory: Style

    /// Creates file picker styles with sensible defaults.
    public init() {
        self.cursor = Style(isBold: true)
        self.disabledCursor = Style(isDim: true)
        self.symlink = Style(foreground: .ansi(.cyan))
        self.directory = Style(foreground: .ansi(.blue), isBold: true)
        self.file = Style()
        self.disabledFile = Style(isDim: true)
        self.permission = Style(isDim: true)
        self.selected = Style(isBold: true)
        self.disabledSelected = Style(isDim: true)
        self.fileSize = Style(isDim: true)
        self.emptyDirectory = Style(isDim: true)
    }
}

// MARK: - FilePicker KeyMap

/// Keybindings for file picker navigation.
public struct FilePickerKeyMap: Sendable {
    public var goToTop: KeyBinding
    public var goToLast: KeyBinding
    public var down: KeyBinding
    public var up: KeyBinding
    public var pageUp: KeyBinding
    public var pageDown: KeyBinding
    public var back: KeyBinding
    public var open: KeyBinding
    public var select: KeyBinding

    /// Creates a file picker key map with default bindings.
    public init() {
        goToTop = KeyBinding(.rune("g"),
                             help: KeyHelp("g", "first"))
        goToLast = KeyBinding(help: KeyHelp("G", "last"))
        down = KeyBinding(.type(.down), .rune("j"),
                          help: KeyHelp("↓/j", "down"))
        up = KeyBinding(.type(.up), .rune("k"),
                        help: KeyHelp("↑/k", "up"))
        pageUp = KeyBinding(.type(.pageUp),
                            help: KeyHelp("pgup", "page up"))
        pageDown = KeyBinding(.type(.pageDown),
                              help: KeyHelp("pgdn", "page down"))
        back = KeyBinding(.type(.left), .rune("h"), .type(.backspace), .type(.escape),
                          help: KeyHelp("←/h", "back"))
        open = KeyBinding(.type(.right), .rune("l"), .type(.enter),
                          help: KeyHelp("→/l", "open"))
        select = KeyBinding(.type(.enter),
                            help: KeyHelp("enter", "select"))
    }
}

// MARK: - ID generation

private let _filePickerIDGenerator = IDGenerator()

// MARK: - FilePicker

/// A file system browser for selecting files or directories.
///
/// Navigate through directories with keyboard controls, filter by
/// file extension, and select files or directories. Directory reads
/// are performed asynchronously via Chai commands.
///
/// ```swift
/// var picker = FilePicker(currentDirectory: FileManager.default.currentDirectoryPath)
/// picker.allowedTypes = ["swift", "txt"]
///
/// // In initialize():
/// picker.initialize()  // reads the initial directory
///
/// // In update():
/// if let cmd = picker.update(msg) { ... }
///
/// // Check for selection:
/// if let path = picker.selectedPath { ... }
///
/// // In body:
/// picker.body
/// ```
public struct FilePicker: View {
    /// The path of the selected file, if any.
    public private(set) var selectedPath: String?

    /// The current directory being displayed.
    public var currentDirectory: String

    /// Allowed file extensions. Empty array means all files.
    public var allowedTypes: [String]

    /// Keybindings.
    public var keyMap: FilePickerKeyMap

    /// Whether to show file permissions.
    public var showPermissions: Bool

    /// Whether to show file sizes.
    public var showSize: Bool

    /// Whether to show hidden files.
    public var showHidden: Bool

    /// Whether directories can be selected.
    public var dirAllowed: Bool

    /// Whether files can be selected.
    public var fileAllowed: Bool

    /// The cursor indicator string.
    public var cursorString: String

    /// Visible height.
    public var height: Int

    /// Whether to auto-adjust height to terminal size.
    public var autoHeight: Bool

    /// Styles.
    public var styles: FilePickerStyles

    // MARK: Private state

    private let _id: Int
    private var _files: [FileEntry]
    private var _selectedIndex: Int
    private var _viewportMin: Int
    private var _viewportMax: Int
    private var _directoryStack: [String]
    private var _indexStack: [Int]
    private var _error: String?

    // MARK: - Initializer

    /// Creates a new file picker.
    ///
    /// - Parameter currentDirectory: The starting directory path.
    public init(currentDirectory: String = "") {
        let dir = currentDirectory.isEmpty
            ? FileManager.default.currentDirectoryPath
            : currentDirectory
        self.selectedPath = nil
        self.currentDirectory = dir
        self.allowedTypes = []
        self.keyMap = FilePickerKeyMap()
        self.showPermissions = true
        self.showSize = true
        self.showHidden = false
        self.dirAllowed = false
        self.fileAllowed = true
        self.cursorString = ">"
        self.height = 10
        self.autoHeight = false
        self.styles = FilePickerStyles()
        self._id = _filePickerIDGenerator.next()
        self._files = []
        self._selectedIndex = 0
        self._viewportMin = 0
        self._viewportMax = 0
        self._directoryStack = []
        self._indexStack = []
        self._error = nil
    }

    // MARK: - ELM interface

    /// Reads the initial directory.
    public func initialize() -> Command? {
        readDirectoryCommand(currentDirectory)
    }

    /// Handles directory read results and key events.
    public mutating func update(_ msg: any Message) -> Command? {
        switch msg {
        case let readDir as FilePickerReadDirMsg where readDir.id == _id:
            _files = readDir.entries
            _error = nil
            currentDirectory = readDir.directory

            // Filter hidden files
            if !showHidden {
                _files = _files.filter { !$0.isHidden }
            }

            // Sort: directories first, then alphabetical
            _files.sort { a, b in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            _selectedIndex = min(_selectedIndex, max(0, _files.count - 1))
            _viewportMin = 0
            _viewportMax = min(height, _files.count)
            return nil

        case let errMsg as FilePickerErrorMsg where errMsg.id == _id:
            _error = errMsg.error
            return nil

        case let size as WindowSizeMsg:
            if autoHeight {
                height = max(3, size.height - 4)  // Leave room for chrome
            }
            return nil

        case let key as KeyMsg:
            return handleKey(key)

        default:
            return nil
        }
    }

    /// Renders the file picker.
    public var body: ViewOutput {
        if let error = _error {
            return ViewOutput(styles.emptyDirectory.styledText("Error: \(error)"))
        }

        guard !_files.isEmpty else {
            return ViewOutput(styles.emptyDirectory.styledText("(empty directory)"))
        }

        var lines: [StyledText] = []
        let start = _viewportMin
        let end = min(_viewportMax, _files.count)

        for i in start..<end {
            let entry = _files[i]
            var line = StyledText()

            // Cursor
            if i == _selectedIndex {
                line += styles.cursor.styledText(cursorString + " ")
            } else {
                line += StyledText(String(repeating: " ", count: cursorString.count + 1))
            }

            // Permissions
            if showPermissions {
                line += styles.permission.styledText(entry.permissions) + StyledText(" ")
            }

            // Size
            if showSize {
                if entry.isDirectory {
                    line += styles.fileSize.styledText(padLeft("-", to: 7)) + StyledText(" ")
                } else {
                    line += styles.fileSize.styledText(padLeft(humanizeBytes(entry.size), to: 7)) + StyledText(" ")
                }
            }

            // Name
            let isAllowed = isFileAllowed(entry)
            if entry.isSymlink {
                line += styles.symlink.styledText(entry.name)
            } else if entry.isDirectory {
                line += styles.directory.styledText(entry.name + "/")
            } else if isAllowed {
                if i == _selectedIndex {
                    line += styles.selected.styledText(entry.name)
                } else {
                    line += styles.file.styledText(entry.name)
                }
            } else {
                line += styles.disabledFile.styledText(entry.name)
            }

            lines.append(line)
        }

        return ViewOutput(lines.joined())
    }

    // MARK: - Selection helpers

    /// Whether a file was selected in the last update.
    ///
    /// Check this after calling `update(_:)` to see if the user
    /// selected a file.
    public func didSelectFile(_ msg: any Message) -> String? {
        guard let key = msg as? KeyMsg else { return nil }
        if keyMap.select.matches(key) || keyMap.open.matches(key) {
            return selectedPath
        }
        return nil
    }

    // MARK: - Private

    private mutating func handleKey(_ key: KeyMsg) -> Command? {
        if keyMap.down.matches(key) {
            if _selectedIndex < _files.count - 1 {
                _selectedIndex += 1
                if _selectedIndex >= _viewportMax {
                    _viewportMin += 1
                    _viewportMax += 1
                }
            }
        } else if keyMap.up.matches(key) {
            if _selectedIndex > 0 {
                _selectedIndex -= 1
                if _selectedIndex < _viewportMin {
                    _viewportMin -= 1
                    _viewportMax -= 1
                }
            }
        } else if keyMap.pageDown.matches(key) {
            _selectedIndex = min(_selectedIndex + height, _files.count - 1)
            updateViewport()
        } else if keyMap.pageUp.matches(key) {
            _selectedIndex = max(_selectedIndex - height, 0)
            updateViewport()
        } else if keyMap.goToTop.matches(key) {
            _selectedIndex = 0
            _viewportMin = 0
            _viewportMax = min(height, _files.count)
        } else if keyMap.goToLast.matches(key) {
            // Match "G" manually since KeyBinding can't distinguish case
            if key.type.isRunes && key.runes == ["G"] {
                _selectedIndex = max(0, _files.count - 1)
                updateViewport()
            }
        } else if keyMap.open.matches(key) {
            return openSelected()
        } else if keyMap.back.matches(key) {
            return goBack()
        }
        return nil
    }

    private mutating func openSelected() -> Command? {
        guard _selectedIndex < _files.count else { return nil }
        let entry = _files[_selectedIndex]

        if entry.isDirectory {
            // Navigate into directory
            _directoryStack.append(currentDirectory)
            _indexStack.append(_selectedIndex)
            _selectedIndex = 0
            let newDir = (currentDirectory as NSString).appendingPathComponent(entry.name)
            return readDirectoryCommand(newDir)
        } else if isFileAllowed(entry) {
            // Select file
            selectedPath = (currentDirectory as NSString).appendingPathComponent(entry.name)
        }

        return nil
    }

    private mutating func goBack() -> Command? {
        guard !_directoryStack.isEmpty else {
            // Try going to parent directory
            let parent = (currentDirectory as NSString).deletingLastPathComponent
            guard parent != currentDirectory else { return nil }
            _selectedIndex = 0
            return readDirectoryCommand(parent)
        }

        let prevDir = _directoryStack.removeLast()
        _selectedIndex = _indexStack.removeLast()
        return readDirectoryCommand(prevDir)
    }

    private func isFileAllowed(_ entry: FileEntry) -> Bool {
        if entry.isDirectory { return dirAllowed }
        guard fileAllowed else { return false }
        if allowedTypes.isEmpty { return true }
        let ext = (entry.name as NSString).pathExtension
        return allowedTypes.contains(ext)
    }

    private mutating func updateViewport() {
        if _selectedIndex < _viewportMin {
            _viewportMin = _selectedIndex
            _viewportMax = _viewportMin + height
        } else if _selectedIndex >= _viewportMax {
            _viewportMax = _selectedIndex + 1
            _viewportMin = _viewportMax - height
        }
        _viewportMin = max(0, _viewportMin)
        _viewportMax = min(_files.count, max(_viewportMax, _viewportMin + height))
    }

    private func readDirectoryCommand(_ directory: String) -> Command {
        let id = self._id
        let dir = directory
        return .perform {
            do {
                let fm = FileManager.default
                let contents = try fm.contentsOfDirectory(atPath: dir)
                let entries: [FileEntry] = contents.compactMap { name in
                    let fullPath = (dir as NSString).appendingPathComponent(name)
                    guard let attrs = try? fm.attributesOfItem(atPath: fullPath) else {
                        return nil
                    }
                    let fileType = attrs[.type] as? FileAttributeType
                    let isDir = fileType == .typeDirectory
                    let isSymlink = fileType == .typeSymbolicLink
                    let size = (attrs[.size] as? UInt64) ?? 0
                    let posix = (attrs[.posixPermissions] as? Int) ?? 0
                    let perms = formatPermissions(posix)

                    return FileEntry(
                        name: name,
                        isDirectory: isDir,
                        isSymlink: isSymlink,
                        size: size,
                        permissions: perms
                    )
                }
                return FilePickerReadDirMsg(id: id, entries: entries, directory: dir)
            } catch {
                return FilePickerErrorMsg(id: id, error: error.localizedDescription)
            }
        }
    }
}

// MARK: - Utility functions

/// Formats a POSIX permission integer as a string like "rwxr-xr-x".
private func formatPermissions(_ mode: Int) -> String {
    func triplet(_ shift: Int) -> String {
        let r = (mode >> (shift + 2)) & 1 == 1 ? "r" : "-"
        let w = (mode >> (shift + 1)) & 1 == 1 ? "w" : "-"
        let x = (mode >> shift) & 1 == 1 ? "x" : "-"
        return r + w + x
    }
    return triplet(6) + triplet(3) + triplet(0)
}

/// Formats a byte count as a human-readable string.
private func humanizeBytes(_ bytes: UInt64) -> String {
    let units = ["B", "K", "M", "G", "T"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024 && unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    if unitIndex == 0 {
        return "\(bytes)B"
    }
    return String(format: "%.1f%@", value, units[unitIndex])
}

/// Pads a string on the left to the given width.
private func padLeft(_ text: String, to width: Int) -> String {
    if text.count >= width { return text }
    return String(repeating: " ", count: width - text.count) + text
}
