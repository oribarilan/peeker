# Spec Delta

## ADDED Requirements

### Requirement: A busy Finder doesn't hold up the Peek panel

Reading Finder's selection for the Peek panel key or an arrow key SHALL give up after half a second. When it gives up on the Peek panel key, the key SHALL go on to Finder, as for a file no plugin opens. When it gives up on an arrow key while the panel shows, the panel SHALL keep showing the file it shows.

#### Scenario: Space while Finder is busy

- **WHEN** Finder takes longer than half a second to answer and the user presses Space on a file
- **THEN** within about half a second the key goes to Finder and its Quick Look handles it

#### Scenario: An arrow while Finder is busy

- **WHEN** the Peek panel shows a file, Finder takes longer than half a second to answer, and the user presses the down arrow
- **THEN** the panel keeps showing the same file and Peeker stays responsive
