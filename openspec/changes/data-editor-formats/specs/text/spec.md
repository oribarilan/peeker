## MODIFIED Requirements

### Requirement: Opens the text files on its list

By default the plugin SHALL open plain text and logs (`txt`, `text`, `log`), config files (`ini`, `conf`, `cfg`, `env`, `properties`), common source code and scripts, and files with no extension (`noExtension`). CSV and TSV files belong to the Table plugin, and JSON, YAML, TOML, XML and property list files to the Data plugin. A file that isn't text (it holds NUL bytes and isn't UTF-16, or decodes in no supported encoding) SHALL show "This doesn't look like a text file." in its tab.

#### Scenario: Extensionless binary file

- **WHEN** the user opens a binary file that has no extension
- **THEN** the tab says the file doesn't look like a text file

#### Scenario: Config file macOS has no type for

- **WHEN** the user opens `nginx.conf`
- **THEN** Plain Text shows it, with no config needed

#### Scenario: A CSV still opens as text on request

- **WHEN** the user opens a `.csv` file and picks Plain Text from Open With
- **THEN** the tab shows the file as text
