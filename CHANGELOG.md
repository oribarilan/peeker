# Changelog

What changes in each release of Peeker, for the people who use it. The newest release comes first; versions follow
[semantic versioning](https://semver.org), and each section becomes that release's notes on GitHub and in the app's
update window. Add to Unreleased as you go; a release moves it into a section of its own.

## [Unreleased]

- Peeker has its own icon, and the menu bar icon is a viewfinder.
- A Markdown link that isn't a web page or email address asks before it opens another app.
- Highlights, text boxes and signatures saved in a PDF no longer carry your Mac account's name as their author.
- The PDF find bar sits below the toolbar instead of under it.
- Rotate & Resize opens below the toolbar instead of covering it.
- Crop and Cancel buttons appear next to a crop rectangle, so a crop can be finished with the mouse.
- A file that takes a moment to open shows a spinner instead of an empty window.
- The Commands menu is gone: zoom and Wrap Lines are in a new View menu, and Edit Mode and the edit tools in a new Tools menu.
- View shows and hides the sidebar (Ctrl+Cmd+S), the toolbar and full screen, and the toolbar has a sidebar button. Whether the sidebar shows, and its width, are remembered for every window.
- File has Open Recent, Open With and Revert to Saved…; the Peeker menu has Hide Others and Show All, Window has Zoom and Bring All to Front, and Help opens the project page.
- Wrap Lines shows whether it's on, with a checkmark in View and a pressed toolbar button.
- Sign no longer has a default shortcut, since Ctrl+Cmd+S now shows and hides the sidebar. A shortcut in the config that a menu item already uses is reported as a problem.
- The panel that opens on Space in Finder is now called the Peek panel, and its config key is `peekPanel` (it was `quickLook`). A config that still says `quickLook` reports it as an unknown key until it's renamed.
- Settings reopens on the pane you last had open, shows an icon for each plugin, and no longer has a zoom button.
- Open at Login and the Default app list moved from Permissions to General.
- The field for adding an extension shows "Add an extension".
- When the shortcut recorder refuses a key, the reason stays on screen until you record again, and VoiceOver reads it.
- The toolbar keeps view commands and edit tools apart, and zoom moved to the View menu only, so a PDF in Edit mode fits the toolbar.
- Opening a file is a little faster: its toolbar buttons are added just after the file shows.
- Document windows can't be shrunk below a usable size.
- When no plugin opens a file, the alert offers Open Settings, which shows where to add its extension.
- Alerts about recovered edits and failed saves have short titles, with the details below.
