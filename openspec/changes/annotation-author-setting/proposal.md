# Proposal

Not scheduled. This records an idea for later; it gets the usual interview, design and tasks before anyone builds it.

## Why

Peeker saves highlights, text boxes and signatures with no author, so the Mac account's name never goes out with a shared file. Some people want their name on their markup, as reviewers and editors usually do, and today there's no way to add one.

## What Changes

- A PDF setting for the author name Peeker writes on the annotations it saves. Empty by default, which keeps today's behavior.
- Settings' PDF pane gets a text field for it, and the config file a key, both following the existing config conventions.
- Only annotations Peeker adds or changes take the name. Annotations already in a file keep their own author.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `pdf`: "Peeker's annotations carry no author" becomes "Peeker's annotations carry the author set in Settings, none by default".
- `settings`: the PDF pane gets the author field.
- `routing-and-config`: a config key for the author name.

## Impact

- `Plugins/pdf/PDFMarks.swift`, where each mark's annotation is made (today it clears the author).
- The plugin would need the setting at save time, which the plugin contract doesn't pass today. How a plugin gets its own settings is a question for the design.
- `Sources/Host/Settings/` and the config reader and schema.

## Questions for the interview

- Should a moved or edited mark take the current name, or keep the one it was saved with?
- Offer the account's full name as a one-click suggestion, or keep the field blank?
- One name for all of Peeker, or a PDF setting only?
