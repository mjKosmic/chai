# terminal-input Specification

## Purpose

Defines how raw bytes read from the terminal become key messages: dedicated
control keys, printable text, and the escape-sequence encodings terminals use
for navigation and function keys, including what happens when a read ends in the
middle of a sequence.

## Requirements

### Requirement: Dedicated control keys are not reported as Ctrl combinations

Bytes that terminals assign a dedicated key — backspace, tab, enter, escape, and
delete — SHALL decode to those keys, even though several of them fall inside the
Ctrl+A…Ctrl+Z byte range.

#### Scenario: Tab is reported as Tab

- **WHEN** the byte `0x09` is read
- **THEN** the key is Tab, not Ctrl+I

#### Scenario: Enter is reported as Enter

- **WHEN** the byte `0x0D` is read
- **THEN** the key is Enter, not Ctrl+M

#### Scenario: Backspace and Delete both report Backspace

- **WHEN** the byte `0x08` or the byte `0x7F` is read
- **THEN** the key is Backspace

#### Scenario: Remaining control bytes report Ctrl letters

- **WHEN** a byte from `0x01` to `0x1A` that has no dedicated key is read
- **THEN** the key is the matching Ctrl+letter combination

#### Scenario: NUL reports Ctrl+@

- **WHEN** the byte `0x00` is read
- **THEN** the key is Ctrl+@

### Requirement: Printable input is delivered as text

A run of printable bytes SHALL decode to a single key message carrying the
decoded characters. Multi-byte UTF-8 sequences SHALL decode as characters rather
than as individual bytes, and bytes that do not form valid UTF-8 SHALL NOT
produce a message for the invalid portion.

#### Scenario: A plain ASCII run

- **WHEN** the bytes for "hello" are read
- **THEN** one key message carries the five characters "hello"

#### Scenario: Multi-byte characters

- **WHEN** the bytes for "héllo" are read
- **THEN** one key message carries five characters, with "é" as a single character

#### Scenario: Wide characters count as one character each

- **WHEN** the bytes for "日本" are read
- **THEN** one key message carries two characters

#### Scenario: Invalid bytes do not become text

- **WHEN** an invalid UTF-8 byte is followed by the byte for "a"
- **THEN** the resulting key message carries only "a"

#### Scenario: Space is Space

- **WHEN** the byte `0x20` is read
- **THEN** the key is Space carrying a single space character

### Requirement: Equivalent escape encodings decode to the same key

Terminals encode the same physical key in different ways. CSI (`ESC [`), SS3
(`ESC O`), and Linux-console (`ESC [[`) encodings SHALL decode to the same
logical key when they represent the same key. An unrecognized escape sequence
SHALL be consumed without producing a message and SHALL NOT leak its constituent
bytes as text.

#### Scenario: Linux-console function keys

- **WHEN** the sequences `ESC [[ A` through `ESC [[ E` are read
- **THEN** they decode to F1 through F5

#### Scenario: xterm function keys

- **WHEN** the sequences `ESC [ 11 ~` through `ESC [ 15 ~` are read
- **THEN** they decode to F1 through F5

#### Scenario: SS3 arrows and function keys

- **WHEN** `ESC O A` through `ESC O D` are read
- **THEN** they decode to the four arrow keys
- **AND WHEN** `ESC O P` through `ESC O S` are read
- **THEN** they decode to F1 through F4

#### Scenario: Home and End

- **WHEN** `ESC [ H`, `ESC [ F`, `ESC [ 1 ~`, or `ESC [ 4 ~` is read
- **THEN** it decodes to Home or End respectively

#### Scenario: Modified arrows

- **WHEN** `ESC [ 1 ; 2 A`, `ESC [ 1 ; 5 A`, or `ESC [ 1 ; 6 A` is read
- **THEN** each decodes to Up carrying the Shift, Ctrl, or Ctrl+Shift modifier
- **AND WHEN** `ESC [ 1 ; 3 A` is read
- **THEN** it decodes to Up with the Alt modifier set

#### Scenario: Shift+Tab is distinct from Tab

- **WHEN** `ESC [ Z` is read
- **THEN** the key is Shift+Tab, distinguishable from Tab

#### Scenario: Unrecognized sequences are skipped

- **WHEN** an unrecognized sequence such as `ESC [ 999 z` is followed by the byte for "a"
- **THEN** no message is produced for the sequence and the next message carries "a"

### Requirement: Incomplete input is held until it can be resolved

When a read may have more data waiting, an incomplete escape sequence or a
truncated UTF-8 sequence at the end of the buffer SHALL be retained and combined
with the next read instead of being reported as unknown or as literal text. When
no more data can follow, the available bytes SHALL be resolved without waiting.

#### Scenario: Partial escape sequence is held

- **WHEN** a read that may have more data ends with the bytes `ESC [ 1`
- **THEN** no message is produced and those bytes are retained

#### Scenario: Partial escape sequence is resolved when final

- **WHEN** the same bytes arrive in a read that cannot have more data
- **THEN** they are resolved and consumed

#### Scenario: Truncated UTF-8 is held

- **WHEN** a read that may have more data ends in the middle of a multi-byte character
- **THEN** no message is produced and the partial character is retained

#### Scenario: Truncated UTF-8 is dropped when final

- **WHEN** a read that cannot have more data ends in the middle of a multi-byte character
- **THEN** no message is produced for the partial character and the input is consumed

### Requirement: A lone or modified escape is interpretable

A bare escape byte SHALL decode to the Escape key when no further data can
follow. Escape followed by a key SHALL decode to that key with the Alt modifier
set. Escape followed by bytes that form no recognized key SHALL decode to Escape
and leave the following bytes to be decoded as their own input.

#### Scenario: Lone Escape

- **WHEN** the escape byte is the final byte of the input
- **THEN** the key is Escape

#### Scenario: Alt-modified key

- **WHEN** the escape byte is followed by the byte for "a"
- **THEN** the key is the character "a" with the Alt modifier set

#### Scenario: Escape before unrecognized bytes

- **WHEN** the escape byte precedes bytes that form no recognized key
- **THEN** Escape is produced and the following bytes are decoded as separate input
