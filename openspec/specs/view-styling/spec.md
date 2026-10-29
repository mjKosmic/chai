# view-styling Specification

## Purpose

Defines the public styling surface for views and styled text: one color value,
style modifiers that apply to any view subtree, deterministic composition, and
the guarantee that styling never changes layout.

## Requirements

### Requirement: One color value at styling call sites

The framework SHALL expose one public color value for application styling:
style values, the view style modifiers, and inline text styling SHALL all accept
it. Named ANSI colors, 256-color entries, and 24-bit colors SHALL be expressible
with it. The renderer's cell-level color type MAY stay public for cell-painting
views but SHALL NOT be required by those APIs.

#### Scenario: Named color on a view and on a string

- **WHEN** an application applies a named ANSI color to a view and to styled text
- **THEN** both produce the same foreground cell value

#### Scenario: True color

- **WHEN** an application applies a 24-bit color to a view
- **THEN** the painted cells carry that 24-bit foreground value

#### Scenario: No conversion at the call site

- **WHEN** an application styles a view or a string
- **THEN** the call site does not need to construct a cell-level color value

### Requirement: Style modifiers apply to any view

Every view SHALL accept foreground, background, and text-attribute modifiers. A
modifier on a container SHALL apply to the glyphs painted by that container's
subtree, and a modifier on a leaf SHALL apply to that leaf. Text SHALL use the
same modifiers as every other view.

#### Scenario: Leaf styling

- **WHEN** a text leaf is given a bold modifier
- **THEN** its painted glyphs carry the bold attribute

#### Scenario: Container styling

- **WHEN** a horizontal stack with two text children is given a foreground modifier
- **THEN** the glyphs of both children carry that foreground

#### Scenario: Wrapper styling

- **WHEN** a padded or bordered view is given a foreground modifier
- **THEN** the glyphs painted by that wrapper and its content carry the foreground

### Requirement: Inner styling wins and attributes accumulate

When style modifiers nest, an outer modifier SHALL NOT overwrite a property that
an inner modifier already set. Text attributes SHALL accumulate across nesting.

#### Scenario: Inner color wins

- **WHEN** an outer modifier sets red and an inner modifier sets blue on the same content
- **THEN** the painted glyphs are blue

#### Scenario: Outer fills unset properties

- **WHEN** an outer modifier sets red and an inner modifier only sets bold
- **THEN** the painted glyphs are red and bold

#### Scenario: Attributes accumulate

- **WHEN** an outer modifier sets bold and an inner modifier sets underline
- **THEN** the painted glyphs are bold and underlined

### Requirement: Styling does not affect layout

Applying a style modifier SHALL NOT change a view's measured size, its wrapping,
its allocated rect, or its visible width. A background SHALL NOT add columns or
rows.

#### Scenario: Measurement is unchanged

- **WHEN** a text view is measured before and after applying foreground and attribute modifiers
- **THEN** both measurements are equal

#### Scenario: Wrapping is unchanged

- **WHEN** a text view is allocated a narrow width with and without style modifiers
- **THEN** it wraps at the same points and paints the same number of rows

#### Scenario: Background adds no size

- **WHEN** a background modifier is applied to a view
- **THEN** its reported width and height are unchanged

### Requirement: Background fills the occupied rect

A background modifier SHALL apply to every cell in the view's occupied rect,
including spaces. Foreground and attribute modifiers SHALL apply to the same
cells without changing the appearance of blank cells.

#### Scenario: Text background includes internal spaces

- **WHEN** a background is applied to a text leaf containing spaces
- **THEN** the spaces between glyphs carry the background

#### Scenario: Container background covers gaps

- **WHEN** a background is applied to a container whose children are narrower than the container
- **THEN** the gap cells inside the occupied rect carry the background

#### Scenario: Background stays inside the occupied rect

- **WHEN** a background is applied to a shrink-wrapped view inside a larger allocation
- **THEN** cells outside the view's occupied rect are unchanged

### Requirement: Inline and modifier styling agree

Styling a value inline and styling the same view with modifiers SHALL produce
identical cells. A style value applied with the style modifier SHALL match the
equivalent inline chain.

#### Scenario: Inline text and modified text

- **WHEN** the same text is styled inline with a foreground and bold, and separately with the view modifiers
- **THEN** the painted cells are identical

#### Scenario: Style value matches the inline chain

- **WHEN** a style value and an equivalent inline chain are applied to the same text
- **THEN** the painted cells are identical

### Requirement: Styling remains structured

View styling SHALL carry color, attributes, and hyperlinks as structured cell
metadata. It SHALL NOT place ANSI escape bytes in view content or in the cell
buffer. ANSI rendering remains available only for output written outside the
live view.

#### Scenario: No escape bytes in the buffer

- **WHEN** any style modifier is applied and the view is embedded
- **THEN** no cell's character is an escape byte

#### Scenario: Out-of-band rendering is unchanged

- **WHEN** an application needs ANSI output for print-above-view text
- **THEN** it can still render a style value to a string for that purpose
