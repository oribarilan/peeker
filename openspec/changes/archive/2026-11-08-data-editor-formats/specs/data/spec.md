## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Opening data is fast

Opening a JSON or YAML file in a window or the Peek panel SHALL be at least as fast as TextEdit opening it, and the Peek panel at least as fast as Quick Look, measured by the benchmark on the same Mac.

#### Scenario: A large JSON file

- **WHEN** the benchmark opens its large JSON fixture with Space
- **THEN** Peeker is at least as fast as Quick Look

#### Scenario: A large YAML file

- **WHEN** the benchmark opens its large YAML fixture with Space
- **THEN** Peeker is at least as fast as Quick Look
