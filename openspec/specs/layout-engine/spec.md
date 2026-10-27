# layout-engine Specification

## Purpose
Top-down allocation of Chai's view tree: parents assign explicit rects,
children report intrinsic sizes, and the allocated rect bounds both layout and
painting.

## Requirements

### Requirement: Measurement is a report, not a constraint

A view's measurement answer SHALL describe the size it would like under the
query context. It SHALL NOT constrain the rect the parent allocates, and a
parent MAY allocate more or less than the reported size.

#### Scenario: Report larger than the allocation

- **WHEN** a child reports a height of three rows and its parent allocates one row
- **THEN** the parent's allocation wins and only one row is painted

#### Scenario: Report smaller than the allocation

- **WHEN** a child reports a smaller size than its parent allocates
- **THEN** the child remains at its reported size inside the allocated rect and does not stretch

### Requirement: An allocated rect is the layout and painting box

Containers SHALL allocate each child an explicit rect, and a child SHALL NOT
paint outside that rect. Content that exceeds the rect SHALL be clipped at the
rect boundary, including at the boundary of a wide character.

#### Scenario: Fixed frame clips overflow

- **WHEN** text longer than a fixed-width frame is embedded in that frame
- **THEN** only the content that fits inside the frame is visible

#### Scenario: Wide character at the clip edge

- **WHEN** a width-2 character would straddle the right edge of an allocated rect
- **THEN** the character is dropped whole and the buffer never contains half a glyph

### Requirement: Containers allocate from their own rules

Containers SHALL decide child rects from their own layout rules and query
context, clamped to the container's own allocation. A stack SHALL shrink-wrap
its cross axis and distribute leftover main-axis space only to flexible
children; a `Fill` child SHALL claim the remainder according to the container's
rule.

#### Scenario: Leading Fill in an HStack

- **WHEN** an HStack at width 8 contains a leading Fill followed by a one-column child
- **THEN** the Fill claims columns 0–6 and the child is placed in column 7

#### Scenario: Flexible spacer shares

- **WHEN** an HStack contains two flexible Spacers with equal fractions around a text child
- **THEN** the leftover width is split between the spacers and the truncation remainder stays unallocated at the trailing end

### Requirement: Text wraps at its allocated width

A Text view SHALL wrap its content at the width it is allocated, not at an
earlier query value. For narrow positive widths it SHALL apply a
minimum-width floor so a wide character is never split, and the measured line
count SHALL match the painted rows.

#### Scenario: Mixed ASCII and wide content

- **WHEN** text containing ASCII and a wide character is allocated one column
- **THEN** it reports and paints the minimum form at the wide character's width rather than dropping the character

#### Scenario: Wrapping inside a padded or bordered wrapper

- **WHEN** text is placed inside a padded or bordered view with a bounded width
- **THEN** the text wraps to the inner width and the wrapper insets remain visible

### Requirement: Root allocation follows renderer mode

The renderer SHALL query the view tree for its content size and then allocate
one root rect. Inline mode SHALL size the buffer from the content height, clamp
to the terminal height by keeping the suffix, and truncate; alt-screen mode
SHALL allocate the full terminal rect and wrap.

#### Scenario: Inline content taller than the terminal

- **WHEN** an inline view reports more rows than the terminal height
- **THEN** the buffer keeps the bottom rows and earlier rows are not painted

#### Scenario: Alt-screen root

- **WHEN** the alternate screen is active
- **THEN** the root receives the full terminal size and wrapping applies within it
