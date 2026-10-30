# Spec Delta

## MODIFIED Requirements

### Requirement: Space in Finder opens the panel

While the app runs, the quick-look key (Space unless the config's `quickLook.key` says otherwise) SHALL show Finder's selected file in a floating panel when an enabled plugin supports it. A bare key SHALL work only while Finder is frontmost and no text field has focus, so typing a space anywhere else is untouched. A key with modifiers SHALL work from any app. `"off"` SHALL turn the panel off. A changed key SHALL take effect as soon as the config is saved.

#### Scenario: Space on a PDF

- **WHEN** the user selects a PDF in Finder and presses Space
- **THEN** Peeker's panel shows the PDF and Finder's Quick Look doesn't open

#### Scenario: Renaming a file

- **WHEN** the user presses Space while renaming a file in Finder
- **THEN** a space is typed into the name and no panel opens

#### Scenario: Changing the key

- **WHEN** the user saves `{"quickLook": {"key": "opt+space"}}`
- **THEN** Option+Space opens the panel from then on, and plain Space goes back to Finder's Quick Look

### Requirement: The app can open at login

Open at Login, in the menu bar icon's menu and in the app menu, SHALL register or unregister the app as a login item, because the panel only works while the app runs. A failure SHALL be reported in an alert.

#### Scenario: Turning on Open at Login

- **WHEN** the user chooses Open at Login
- **THEN** Peeker starts at the next login and the panel works without launching it by hand
