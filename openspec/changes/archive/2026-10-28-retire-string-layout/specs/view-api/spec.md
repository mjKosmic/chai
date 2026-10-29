# Spec Delta

## Purpose

Defines the supported public surface for composing a terminal view in Chai:
what an application builds its `body` from, how layout is expressed, and how
styling and custom containers participate.

## ADDED Requirements

### Requirement: Views compose through one tree

A model's body SHALL be any view value. A view tree MAY combine leaves and
containers, and a body consisting of a single leaf SHALL be complete and valid.
Containers SHALL be optional, not required to produce a valid frame.

#### Scenario: Body with a single leaf

- **WHEN** a model returns a body containing only a text leaf
- **THEN** that text is measured and painted as the whole frame, with no container required

#### Scenario: Nested containers

- **WHEN** a vertical stack contains a horizontal stack and a text leaf
- **THEN** the tree is measured and painted as one unit within the terminal rect

### Requirement: Layout is expressed only through the view tree

The framework SHALL provide exactly one layout model: composable view values
and view modifiers. It SHALL NOT provide a parallel set of string-returning
layout operations for borders, padding, margins, alignment, joining, wrapping,
or static list and tree rendering.

#### Scenario: Padded and bordered content

- **WHEN** an application needs padding inside a border around some text
- **THEN** it applies the padding and border modifiers to the view containing that text

#### Scenario: No string layout unit

- **WHEN** an application has a finished string that needs a layout
- **THEN** it places the string in a view and lays the view out; the string itself is not a layout unit

### Requirement: Styled content carries structured attributes

Styled content in a view tree SHALL carry foreground color, background color,
text attributes, and hyperlinks as structured values, not as ANSI escape bytes
inside visible text. ANSI-encoded text SHALL NOT be accepted as view content.

#### Scenario: Styling survives layout

- **WHEN** styled text is placed inside a stack, frame, padding, or border
- **THEN** its color, attributes, and hyperlink are preserved and its escape codes never count toward visible width

#### Scenario: ANSI text is rejected as view content

- **WHEN** a caller passes a string containing ANSI escape bytes as view content
- **THEN** the framework rejects it rather than rendering the bytes as literal characters

#### Scenario: Styled border edges

- **WHEN** a border modifier is given a style for a border edge
- **THEN** that edge's glyphs carry the style as structured attributes and the content inside the border is not styled by it

### Requirement: Custom containers are a supported extension point

A view type SHALL be able to participate in layout by reporting its size,
placing its children, enumerating them, and declaring flexibility, without
changes to the framework. The allocated rect SHALL bound both the custom
container's layout decision and its painting.

#### Scenario: A custom container lays out its child

- **WHEN** an application defines a container that insets its child and places it in the tree
- **THEN** the child observes the rect the custom container allocated and cannot paint outside it

#### Scenario: Custom container inside a built-in stack

- **WHEN** a custom container is used as a child of a built-in stack
- **THEN** the stack queries and allocates it through the same rules as any built-in view

### Requirement: A finished raster can be clamped

A finished raster view MAY be clamped to a maximum column width or row count
without entering the layout engine. Clamping SHALL truncate each line to at
most the requested number of display columns, SHALL drop a wide character that
would straddle the boundary rather than split it, and SHALL leave shorter
content unchanged.

#### Scenario: Clamping columns

- **WHEN** a raster line of four display columns is clamped to three
- **THEN** the result occupies at most three columns and never contains half a wide character

#### Scenario: Clamping rows

- **WHEN** a raster of four lines is clamped to two rows
- **THEN** only the first two lines remain

#### Scenario: Clamping does not pad

- **WHEN** a raster narrower than the clamp limit is clamped
- **THEN** its content and reported width are unchanged
