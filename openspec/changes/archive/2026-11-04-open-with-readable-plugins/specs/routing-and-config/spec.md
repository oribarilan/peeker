# Spec Delta

## MODIFIED Requirements

### Requirement: Users can turn plugins off

`"plugins": {"<id>": {"enabled": false}}` SHALL turn off that plugin. A disabled plugin SHALL never open files: it SHALL drop out of default routing, the Open With menu and the Peek panel. No other plugin SHALL take its extensions.

#### Scenario: Disabling the image plugin

- **WHEN** the config contains `{"plugins": {"image": {"enabled": false}}}`
- **THEN** images no longer open in Peeker, and Space on an image falls through to Finder's Quick Look

#### Scenario: Disabling Markdown

- **WHEN** the Markdown plugin is off and the user opens a `.md` file
- **THEN** no plugin opens it by default, and Open With offers the other enabled plugins that can read it

### Requirement: Open With switches the plugin for one tab

Each Editor window SHALL have an Open With control in its toolbar (tooltip "Open With") and File > Open With, both listing the file's owner first, then each other enabled plugin that reads the file's type, and always the plugin the tab shows; the menu SHALL check the current one. Plain Text SHALL read any text, Markdown only Markdown files, Image the image types it can decode, PDF only PDFs. A file's type SHALL come from macOS, which types an extensionless file by its contents. With only one plugin listed, the toolbar control SHALL be hidden. Choosing another plugin SHALL reopen that tab with it; a plugin that can't read the file SHALL show its error in the tab. Unsaved edits SHALL be resolved first (Save, Don't Save or Cancel), and cancelling SHALL leave the tab and the control unchanged.

#### Scenario: View Markdown as plain text

- **WHEN** the user picks Plain Text in Open With on a Markdown tab with no unsaved edits
- **THEN** the tab reopens showing the Markdown source in the text plugin

#### Scenario: From the File menu

- **WHEN** the user chooses File > Open With > Plain Text on a Markdown tab with no unsaved edits
- **THEN** the tab reopens in the text plugin, and File > Open With now checks Plain Text

#### Scenario: Only plugins that read the file

- **WHEN** a Markdown file is open in a window and every plugin is on
- **THEN** Open With lists Markdown and Plain Text, and not Image or PDF

#### Scenario: The owner is always listed

- **WHEN** the user added `json` to Markdown's list and opens a JSON file
- **THEN** Open With lists Markdown first, then Plain Text

#### Scenario: A file only one plugin reads

- **WHEN** a photo is open in a window
- **THEN** the toolbar has no Open With control

#### Scenario: A file with no extension

- **WHEN** a text file named `README` with no extension is open in a window
- **THEN** Open With lists only Plain Text, so the toolbar has no Open With control

#### Scenario: A plugin that can't read the file

- **WHEN** a file named `photo.png` holds no image and opens in a window
- **THEN** the tab says the file isn't a readable image

#### Scenario: The current plugin stays listed

- **WHEN** a tab shows a file in a plugin that doesn't read its type, such as one reopened from crash recovery after its extension moved to another plugin
- **THEN** Open With lists that plugin too, checked
