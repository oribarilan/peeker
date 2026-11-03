# Changelog

What changes in each release of Peeker, for the people who use it. The newest release comes first; versions follow
[semantic versioning](https://semver.org), and each section becomes that release's notes on GitHub and in the app's
update window. Add to Unreleased as you go; a release moves it into a section of its own.

## [Unreleased]

- Large Markdown files open in a window several times faster, styled from the top while the rest follows.
- Markdown and text files open with the cursor at the start instead of the end.
- Dragging a PDF page's thumbnail shows a bar where the page will land.
- The Wrap Lines button shows lines of text instead of an arrow that looked like Back.
- The sidebar button sits over the sidebar next to the window buttons, as in Finder.
- The Markdown outline highlights a heading under the pointer and marks the section the cursor is in.
- Find in Markdown and text files marks matches in the text theme's find color, without dimming the rest of the text.
- Settings has an Appearance pane: pick the text theme from cards that show what each one looks like, hold Peeker light or dark whatever the Mac uses, and set the text's look on its own, such as a light page in a dark app. The same choices are `appearance` and `textAppearance` in the config.
- Markdown and text files can use a text theme: System, Paper, Slate, Graphite, Ink, Catppuccin, Tokyo Night or High Contrast, each with a light and a dark look. Pick one in Settings > General or with `textTheme` in the config; windows and the Peek panel change at once, and printing stays black on white.
- Markdown files open in a window ready to edit, as source styled while you type: headings larger, bold and italic shown, code in a monospaced font, and the Markdown markers dimmed. The Peek panel on Space still shows them rendered, and printing prints them rendered.
- Ticking a Markdown task is now an edit: click the box in a window, then save with Cmd+S. The Peek panel's task boxes no longer react to clicks. In a window, Cmd-click opens a link.
- Markdown files saved in Windows-1252, Mac Roman or UTF-16 open, and saving keeps their encoding and line endings.
- Windows open every file ready to edit: there's no Edit button, Edit Mode item or Cmd+E any more. PDF form fields fill in directly, as in Preview, and C crops an image right after it opens. The Peek panel on Space still only views.
- A file Peeker can't edit, such as a digitally signed PDF or an animated GIF, shows its edit tools greyed out with the reason, and a note under the toolbar says why.
- The Peek panel's button reads Open in Peeker, so it's easy to tell from Finder's Quick Look.
- With no edit tools for the file in front, the Tools menu shows No Tools.
- Plugin shortcuts in the config moved from `plugins.<id>.commands` to `plugins.<id>.tools`, and Settings lists them under Tools. A config that still says `commands` reports it as an unknown key until it's renamed.
- Peeker has its own icon, and the menu bar icon is a viewfinder.
- A Markdown link that isn't a web page or email address asks before it opens another app.
- Highlights, text boxes and signatures saved in a PDF no longer carry your Mac account's name as their author.
- The PDF find bar sits below the toolbar instead of under it.
- Rotate & Resize opens below the toolbar instead of covering it.
- Crop and Cancel buttons appear next to a crop rectangle, so a crop can be finished with the mouse.
- A file that takes a moment to open shows a spinner instead of an empty window.
- The Commands menu is gone: zoom and Wrap Lines are in a new View menu, and the edit tools in a new Tools menu.
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
