# Spec Delta

## MODIFIED Requirements

### Requirement: Slow file work never freezes the app

Reading, decoding and saving a file SHALL run off the main thread. While a file opens in the Editor or the Peek panel and nothing of it shows yet, a spinner SHALL appear in the middle of the content once the open has taken about half a second, and go away when the file or its failure appears. An open that finishes sooner SHALL never show it. The rest of the app SHALL keep responding.

#### Scenario: Opening a large log

- **WHEN** the user opens an 86 MB log and immediately switches to another tab
- **THEN** the other tab responds at once, and the log appears when it's ready

#### Scenario: A slow open shows a spinner

- **WHEN** opening a file in the Editor takes two seconds
- **THEN** a spinner shows in the middle of the empty content from about half a second on, and goes away when the file appears

#### Scenario: A slow open in the Peek panel

- **WHEN** the user presses Space on a 24,000-pixel PNG that takes two seconds to open
- **THEN** the Peek panel shows a spinner in the middle from about half a second on, and the image replaces it

#### Scenario: A fast open shows none

- **WHEN** a file opens in under half a second
- **THEN** no spinner is ever drawn

#### Scenario: A failed open replaces the spinner

- **WHEN** a slow open fails
- **THEN** the spinner goes away and the failure shows in its place
