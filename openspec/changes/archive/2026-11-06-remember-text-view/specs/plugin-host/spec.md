# Spec Delta

## ADDED Requirements

### Requirement: Plugins can keep small preferences

The host SHALL give a plugin, each time it opens a file in a window or the Peek panel, a place to keep small preferences between launches, such as a text size, stored in the app's preferences under the plugin's id. Unit tests and benchmarks SHALL get none, so they never read or change the user's preferences. A plugin SHALL ignore a stored value it doesn't accept and use its default.

#### Scenario: A test opens a file

- **WHEN** a unit test opens a text file and zooms in
- **THEN** nothing is written to the app's preferences
