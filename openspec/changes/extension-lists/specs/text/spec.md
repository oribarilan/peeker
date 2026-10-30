# Spec Delta

## ADDED Requirements

### Requirement: Opens the text files on its list

By default the plugin SHALL open plain text and logs (`txt`, `text`, `log`), tables (`csv`, `tsv`), structured data (`json`, `xml`, `yaml`, `yml`, `toml`), config files (`ini`, `conf`, `cfg`, `env`, `properties`), common source code and scripts, and files with no extension (`noExtension`). A file that isn't text (it holds NUL bytes and isn't UTF-16, or decodes in no supported encoding) SHALL show "This doesn't look like a text file." in its tab.

#### Scenario: Extensionless binary file

- **WHEN** the user opens a binary file that has no extension
- **THEN** the tab says the file doesn't look like a text file

#### Scenario: Config file macOS has no type for

- **WHEN** the user opens `nginx.conf`
- **THEN** Plain Text shows it, with no config needed

## REMOVED Requirements

### Requirement: Opens text and untyped files routed to it

**Reason**: Plain Text opens the extensions on its list instead of everything macOS types as text plus routed files (see "Opens the text files on its list").

**Migration**: Add an extension the list lacks to `plugins.text.extensions` in the config.
