## ADDED Requirements

### Requirement: A document can follow links

A document SHALL be able to hand the host a link to a local file, its own file included, with an optional place name such as a heading's; to tell the host where it is scrolled; and to go to a place by name, saying whether that place exists. The host SHALL decide where each link goes and keep the history. A document that doesn't take part SHALL work as before, with no Back or Forward.

#### Scenario: Markdown hands over a link

- **WHEN** the user follows a link to `other.md` in a Markdown document
- **THEN** the host, not the plugin, decides whether it opens in the same tab, its own tab or another app

#### Scenario: A plugin that doesn't take part

- **WHEN** a text file is open in the Editor
- **THEN** its window has no Back or Forward buttons and works as it did before

### Requirement: The Go menu

Go SHALL offer Back (Cmd-[) and Forward (Cmd-]), which move through the front Editor tab's history. Each SHALL be greyed out when there's no place in its direction or no Editor window is in front.

#### Scenario: The Peek panel in front

- **WHEN** only the Peek panel and Settings are open
- **THEN** Go > Back and Go > Forward are greyed out

## RENAMED Requirements

- FROM: `### Requirement: The menu bar holds seven menus`
- TO: `### Requirement: The menu bar holds eight menus`

## MODIFIED Requirements

### Requirement: The menu bar holds eight menus

The menu bar SHALL hold Peeker, File, Edit, View, Go, Tools, Window and Help, in that order, whichever window is in front and whatever its plugin. A document's view tools SHALL be listed in View and its edit tools in Tools, with the shortcuts they have.

#### Scenario: An image in front
- **WHEN** an image document is in front
- **THEN** View lists Zoom In, Zoom Out, Zoom to Fit and Actual Size, and Tools lists Crop and Rotate & Resize

#### Scenario: Switching tabs
- **WHEN** the user switches from a PDF tab to a Markdown tab
- **THEN** the same eight menus stay in the menu bar, and View and Tools list the Markdown document's tools
