# Spec Delta

## MODIFIED Requirements

### Requirement: Styled content carries structured attributes

Styled content in a view tree SHALL carry foreground color, background color,
text attributes, and hyperlinks as structured values, not as ANSI escape bytes
inside visible text. A string supplied as view content that contains ANSI escape
sequences SHALL be sanitized before measurement and painting: the escape
sequences SHALL be removed in every build configuration, and the remaining text
SHALL be treated as plain content with the terminal's default styling.

#### Scenario: Styling survives layout

- **WHEN** styled text is placed inside a stack, frame, padding, or border
- **THEN** its color, attributes, and hyperlink are preserved and its escape codes never count toward visible width

#### Scenario: ANSI text is rejected as view content

- **WHEN** a caller passes a string containing ANSI escape bytes as view content
- **THEN** the framework rejects the escape sequences rather than rendering the bytes as literal characters, paints only the remaining plain text with default styling, and the removed bytes contribute no display width

#### Scenario: Operating-system-command sequences are removed

- **WHEN** a caller passes a string containing an operating-system-command sequence, such as a window-title or hyperlink sequence
- **THEN** the sequence and its parameters are removed and only the surrounding text is painted

#### Scenario: Sanitization is not conditional on build configuration

- **WHEN** the same content containing escape bytes is used in a development or an optimized build
- **THEN** both builds paint the same sanitized text

#### Scenario: Styled border edges

- **WHEN** a border modifier is given a style for a border edge
- **THEN** that edge's glyphs carry the style as structured attributes and the content inside the border is not styled by it
