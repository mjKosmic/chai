# Spec Delta

## ADDED Requirements

### Requirement: Overlay composition is part of the public surface

The framework SHALL provide a ZStack container that overlays its children. It
SHALL be usable anywhere a view is accepted — as a model body, a root view, or a
child of another container — and SHALL compose with the existing modifiers and
styling.

#### Scenario: ZStack as the model body

- **WHEN** a model's body is a ZStack
- **THEN** the stack is measured and painted as the whole frame

#### Scenario: ZStack nested in a stack

- **WHEN** a ZStack is a child of a VStack or HStack
- **THEN** the parent queries and allocates it through the same rules as any other view

#### Scenario: Styling a ZStack

- **WHEN** a style modifier is applied to a ZStack
- **THEN** the style applies to the cells the stack's children paint within its occupied rect

#### Scenario: Custom child inside ZStack

- **WHEN** a custom container is placed inside a ZStack
- **THEN** the child observes the rect the ZStack allocated and cannot paint outside it

### Requirement: Combined alignment positions content on both axes

The public alignment value used by ZStack SHALL carry one horizontal and one
vertical alignment. It SHALL provide named presets for common positions, accept
custom fractional positions on each axis, and default to centered.

#### Scenario: Named alignment presets

- **WHEN** an application selects a named alignment such as top-left, center, or bottom-right
- **THEN** the corresponding horizontal and vertical positions are used

#### Scenario: Custom fractional alignment

- **WHEN** an application supplies custom horizontal and vertical fractions
- **THEN** the child is positioned proportionally on each axis

#### Scenario: Default alignment

- **WHEN** a ZStack is created without an alignment
- **THEN** children are centered horizontally and vertically
