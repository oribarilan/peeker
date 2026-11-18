# Spec Delta

## MODIFIED Requirements

### Requirement: Recovered edits that can't go back into a window aren't silently lost

When recovered text can't be reopened (its file is gone, no enabled plugin opens it, or the file now opens read-only), the text SHALL go to the clipboard, several texts together under their file paths, with an alert saying why. Its recovery copy SHALL be removed only once the clipboard accepted it. Recovered highlights whose file is gone or has no enabled plugin SHALL be reported in an alert and dropped. Recovered highlights the current view can't show SHALL be kept for a later open. An alert about a file no enabled plugin opens SHALL say Peeker doesn't open it, without the word "plugin".

#### Scenario: File deleted before relaunch

- **WHEN** the app relaunches with recovered text for a file that no longer exists
- **THEN** the text is on the clipboard and an alert says the file no longer exists

#### Scenario: Its format turned off before relaunch

- **WHEN** the app relaunches with recovered text for `notes.md` while Markdown is turned off
- **THEN** the text is on the clipboard and the alert says Peeker doesn't open notes.md
