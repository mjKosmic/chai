# Spec Delta

## ADDED Requirements

### Requirement: ZStack overlays children in declaration order

A ZStack SHALL measure every child against the same width and height query
context and SHALL paint children in declaration order, so a later child covers
an earlier one where they overlap. A child SHALL NOT paint outside the rect the
ZStack allocates to it.

#### Scenario: Overlapping children paint in declaration order

- **WHEN** a ZStack contains one child at the top-left and a later child that overlaps it
- **THEN** the later child's content is visible where the two overlap

#### Scenario: Child overflow is clipped to its rect

- **WHEN** a ZStack child reports more content than the rect the stack allocates
- **THEN** only the content inside that rect is painted and the overflow is clipped

#### Scenario: Empty children overlay nothing

- **WHEN** a ZStack contains only children that measure 0×0
- **THEN** the stack measures 0×0 and paints no rows

#### Scenario: Later child replaces earlier cell styling

- **WHEN** a later child paints a cell that an earlier child painted
- **THEN** the later child's cell replaces the earlier cell entirely, including its background

### Requirement: ZStack shrink-wraps to its largest child

A ZStack SHALL occupy the maximum reported width and the maximum reported
height across its children. It SHALL NOT stretch a smaller child to the
occupied size, and a child that reports the query context, such as a Fill view,
SHALL grow the stack toward the assigned dimensions.

#### Scenario: Largest child defines both axes

- **WHEN** a ZStack contains a 2×3 child and a 5×1 child
- **THEN** the stack occupies 5×3

#### Scenario: Fill child grows the stack

- **WHEN** a ZStack containing a Fill is offered an 8×4 query context
- **THEN** the Fill reports 8×4 and the stack occupies 8×4

#### Scenario: Small child stays at its reported size

- **WHEN** a ZStack occupies 5×3 and contains a 2×1 child
- **THEN** the child paints at its reported 2×1 size rather than stretching to the stack's box

#### Scenario: Assignment larger than content

- **WHEN** a ZStack that occupies 5×3 is allocated an 8×6 rect
- **THEN** its children remain positioned within the 5×3 occupied box

#### Scenario: Context-sensitive child re-reports under the embed context

- **WHEN** a child's reported size depends on the query context and the embed-time rect differs from the measure-time context
- **THEN** the stack uses the child's embed-time report, clamped to the stack's rect

### Requirement: ZStack aligns each child within its occupied box

A ZStack SHALL position each child inside the occupied box using its combined
horizontal and vertical alignment. The horizontal and vertical shortages SHALL
be computed independently, and an odd shortage SHALL use the same truncated
fractional offset as the one-dimensional stacks.

#### Scenario: Center is the default

- **WHEN** a 2×1 child sits in a 6×3 ZStack with the default alignment
- **THEN** the child is placed two columns from the left and one row from the top

#### Scenario: Corner alignment

- **WHEN** a ZStack uses a bottom-right alignment and the child is smaller than the occupied box
- **THEN** the child's right and bottom edges are flush with the occupied box

#### Scenario: Odd horizontal shortage truncates

- **WHEN** a 2-wide child is centered in a 5-wide occupied box
- **THEN** the child's left edge is one column from the left, matching the stacks' truncated fractional offset

#### Scenario: Multi-line child aligns as one block

- **WHEN** a multi-line child is centered vertically in a taller ZStack
- **THEN** the whole child block is offset by the vertical shortage rather than each line being centered independently

#### Scenario: Wide characters count by display width

- **WHEN** a ZStack child contains wide characters and is aligned in a wider occupied box
- **THEN** the child's display width, not its character count, determines its placement

### Requirement: ZStack does not distribute flexible space

A ZStack SHALL NOT distribute leftover space to flexible children. A flexible
Spacer SHALL report and occupy zero there, and only the main-axis stacks SHALL
distribute flexibility.

#### Scenario: Flexible spacer inside ZStack

- **WHEN** a ZStack contains a flexible Spacer alongside a text child
- **THEN** the spacer contributes no size and the stack occupies the text child's size
