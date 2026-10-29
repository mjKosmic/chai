# Spec Delta

## ADDED Requirements

### Requirement: Extended underline decoration is carried structurally

Underline style variants and underline color SHALL be carried as structured cell
metadata, so a view styled with them paints the same decoration as the equivalent
inline styled text. A double, curly, dotted, or dashed underline SHALL be
preserved rather than collapsed to a single underline.

#### Scenario: Double underline through a view modifier

- **WHEN** a view is given a style with a double underline
- **THEN** its painted cells carry the double-underline decoration rather than a single underline

#### Scenario: Curly, dotted, and dashed underlines

- **WHEN** a view is given a style with a curly, dotted, or dashed underline
- **THEN** each painted cell carries the requested underline variant

#### Scenario: Underline color

- **WHEN** a style sets an underline color together with an underline style
- **THEN** the painted cells carry that underline color independently of the foreground color

#### Scenario: Underline color without an underline

- **WHEN** a style sets an underline color but no underline style
- **THEN** no underline and no underline color are painted

#### Scenario: Inline and modifier styling agree for underlines

- **WHEN** the same style with an extended underline is applied inline and with the view modifier
- **THEN** the painted cells are identical

#### Scenario: Inner underline wins

- **WHEN** an outer modifier sets a double underline and the inner content already paints a curly underline
- **THEN** the painted cells keep the curly underline

### Requirement: Terminal color capability is detected from the environment

The framework SHALL detect the connected terminal's color capability from the
environment and output state: color SHALL be disabled when `NO_COLOR` is set or
when output is not a terminal; 24-bit capability SHALL be recognized when
`COLORTERM` names true color, matched without regard to letter case; and
256-color capability SHALL be recognized from `TERM`.

#### Scenario: Color is disabled by NO_COLOR

- **WHEN** `NO_COLOR` is present in the environment
- **THEN** the detected capability is no color

#### Scenario: Color is disabled without a terminal

- **WHEN** output is not a terminal
- **THEN** the detected capability is no color

#### Scenario: COLORTERM matching is case-insensitive

- **WHEN** `COLORTERM` is `truecolor`, `TrueColor`, `24bit`, or `24BIT`
- **THEN** the detected capability is 24-bit color

#### Scenario: 256-color terminals

- **WHEN** `TERM` contains `256color`
- **THEN** the detected capability is 256 colors

#### Scenario: Plain terminals fall back to 16 colors

- **WHEN** output is a terminal and no capability variable names a higher profile
- **THEN** the detected capability is 16 colors
