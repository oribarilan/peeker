# data Specification

## Purpose
The Data plugin shows structured data files as a collapsible tree with an outline, switches to their text, and edits JSON in the tree while keeping the rest of the file as it was.

## Requirements

### Requirement: Opens JSON files as a tree

By default the Data plugin SHALL open `json` and `jsonc` files as a tree: each key or array index with its value, objects and arrays collapsible with their size shown, the first level open. Comments and trailing commas SHALL be accepted. A file that isn't text SHALL show "This doesn't look like a text file." in its tab.

#### Scenario: A nested file

- **WHEN** the user opens `{"name": "app", "deps": {"a": 1, "b": 2}}`
- **THEN** the tree shows name with app, and deps as an object of 2 keys that opens to show a and b

#### Scenario: Comments

- **WHEN** a `.jsonc` file has `// comments` and a trailing comma
- **THEN** it opens as a tree without an error

### Requirement: Tree or text

View > Show Text SHALL switch to the file's text, colored by its syntax and editable in the Editor, and choosing it again SHALL switch back to the tree, showing the text as it now is. The last view chosen SHALL be how every data file opens, in windows and across launches.

#### Scenario: Editing the text

- **WHEN** the user switches to the text, changes a value and switches back
- **THEN** the tree shows the new value

### Requirement: The outline

The sidebar SHALL list the top-level keys of an object, or the items of an array, and clicking one SHALL go to it: selecting it in the tree, or in the text putting the cursor on its line.

#### Scenario: Jumping to a key

- **WHEN** the user clicks scripts in the outline of a package.json
- **THEN** the tree selects scripts and scrolls it into view

### Requirement: Syntax errors

A file that doesn't parse SHALL open in the text view under a bar naming the line and the problem, such as "Line 4: Expected a comma or }". The tree SHALL be unavailable, with that reason, until the text parses again, and the bar SHALL follow the text as it's edited.

#### Scenario: A missing comma

- **WHEN** the user opens a JSON file missing a comma on line 4
- **THEN** the text shows under a bar saying line 4 has a problem, and fixing it removes the bar

### Requirement: Editing JSON in the tree

In the Editor the user SHALL be able to edit a value, rename a key, add an item after the selection, add a child to an object or array, delete the selected items, and move an item within its parent by dragging. A value typed into a string stays a string; a value typed into anything else SHALL be a number, true, false or null when it reads as one, and a string otherwise. Each change SHALL be one undo step, shared with the text view's undo, mark the document edited and stay pending until Cmd+S.

#### Scenario: Changing a number

- **WHEN** the user double-clicks the value 1 of a and types 5
- **THEN** a shows 5, and Undo brings back 1

#### Scenario: Adding a key

- **WHEN** the user selects b and chooses Add Item
- **THEN** a new key follows b, its name ready to type

### Requirement: Tree edits keep the rest of the file

A tree edit SHALL change only its own part of the text: the edited value or key, or the item added, removed or moved, with its comma and line. Indentation for added items SHALL follow the file's. Comments, formatting and every other item SHALL stay byte for byte. Saving SHALL keep the file's encoding, byte order mark and line endings, and SHALL ask before saving as UTF-8 when the encoding can't hold the text, as Plain Text does.

#### Scenario: A comment survives an edit

- **WHEN** a file has a comment above b and the user changes a's value and saves
- **THEN** the file differs only in a's value

### Requirement: Large data files

A data file over 10 MB SHALL open read-only, as text files do, with the reason shown. A file over 16 MB, whose text shows only in part, SHALL open as text only, saying why: its tree would take about twelve times its size in memory. The Peek panel SHALL show the tree without editing.

#### Scenario: A large export

- **WHEN** the user opens a 12 MB JSON file in the Editor
- **THEN** the tree shows and editing is greyed out with the reason

#### Scenario: A very large export

- **WHEN** the user opens a 40 MB JSON file
- **THEN** its text shows under a bar saying files over 16 MB show as text only, and Show Text can't be turned off

### Requirement: Opening data is fast

Opening a JSON or YAML file in a window or the Peek panel SHALL be at least as fast as TextEdit opening it, and the Peek panel at least as fast as Quick Look, measured by the benchmark on the same Mac.

#### Scenario: A large JSON file

- **WHEN** the benchmark opens its large JSON fixture with Space
- **THEN** Peeker is at least as fast as Quick Look

#### Scenario: A large YAML file

- **WHEN** the benchmark opens its large YAML fixture with Space
- **THEN** Peeker is at least as fast as Quick Look

### Requirement: Opens YAML, TOML, XML and property lists as a tree

By default the Data plugin SHALL also open `yaml`, `yml`, `toml`, `xml` and `plist` files as a tree, with the same outline, Show Text toggle, remembered view and syntax-error bar as JSON. A YAML file holding several documents SHALL show each document as an item. YAML anchors and tags SHALL show without their markers, and an alias as written.

#### Scenario: A YAML manifest

- **WHEN** the user opens a YAML file with `name: app` and a `ports` list of 80 and 443
- **THEN** the tree shows name with app, and ports as 2 items that open to show 80 and 443

#### Scenario: A TOML table

- **WHEN** the user opens a `Cargo.toml` with a `[dependencies]` table holding `serde = "1"`
- **THEN** the tree shows dependencies as 1 key that opens to show serde with 1

### Requirement: XML elements in the tree

An XML file's tree SHALL list the root element's attributes and child elements. An element with only text SHALL show its text as its value; an element with attributes or child elements SHALL open to show each attribute as `@name` with its value, then its child elements and any text as `#text`, in file order. Comments, processing instructions and the doctype SHALL not show.

#### Scenario: A Maven file

- **WHEN** the user opens `<project><version>1.0</version><build lang="java"><x/></build></project>`
- **THEN** the tree shows version with 1.0, and build as 2 children that open to show @lang with java, and x

### Requirement: Property lists show their keys and values

A property list SHALL show as its dictionaries, arrays and values rather than as XML elements: each dictionary key with its value, strings, dates and data as text, integers and reals as numbers, and true and false. A binary property list SHALL open as a tree too, and Show Text SHALL show its XML form read-only, with the reason. Saving As SHALL copy the binary file unchanged.

#### Scenario: An Info.plist

- **WHEN** the user opens a property list whose dictionary has `CFBundleName` set to Peeker
- **THEN** the tree shows CFBundleName with Peeker

#### Scenario: A binary property list

- **WHEN** the user opens a binary property list and chooses Show Text
- **THEN** its XML form shows and can't be edited

### Requirement: Other formats change in the text

Only JSON SHALL be edited in the tree. For YAML, TOML, XML and property lists the tree SHALL be read-only, its edit tools greyed out with a reason pointing to Show Text, and their text SHALL edit, undo and save as JSON's text does, the tree following the text.

#### Scenario: Editing a YAML value

- **WHEN** the user switches a YAML file to the text, changes `name: app` to `name: web` and switches back
- **THEN** the tree shows name with web, and Add Item stays greyed out

### Requirement: Forms the tree can't show

A file using a form the tree doesn't read, such as a YAML complex key (`? `), SHALL open in the text under a bar naming the line and saying the tree can't show that form, rather than calling the file broken.

#### Scenario: A complex key

- **WHEN** the user opens a YAML file whose line 3 starts with `? `
- **THEN** the text shows under a bar saying line 3 uses a form the tree can't show

### Requirement: Zooming a data file

Zoom In and Zoom Out (Cmd+= and Cmd+-) SHALL change the text size of the tree and of Show Text together, and Actual Size (Cmd+0) SHALL go back to the default size. They SHALL be listed in the View menu only. The size SHALL be remembered across files and launches, in a window or the Peek panel, as plain text's is; files already open keep their own until changed.

#### Scenario: Zooming a JSON tree
- **WHEN** the user presses Cmd+= in a JSON file's tree and switches to Show Text
- **THEN** both the tree and the text are larger, and Cmd+0 puts both back
