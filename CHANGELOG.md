# Changelog

What changes in each release of Peeker, for the people who use it. The newest release comes first; versions follow
[semantic versioning](https://semver.org), and each section becomes that release's notes on GitHub and in the app's
update window. Add to Unreleased as you go; a release moves it into a section of its own.

## [Unreleased]

- With Open at Login on, Peeker starts quietly at login instead of opening Settings, and after an update it waits for your first window to say what's new.
- A shortcut refused in Settings or the config names the menu item without its ellipsis: "⌘P is used by Print."
- Animated images open paused on their first frame when Reduce Motion is on, and View > Play Animation plays and pauses them from the menu, checked while they play.
- The PDF tools have single-letter keys: T for Text Box, S for Sign and H for Highlight, like C for Crop in images; they type as usual while a form field or text box has the keyboard. Rotate Left and Rotate Right no longer have keys by default. A key set in Settings or the config stays as it is.
- Each toolbar tool sits on its own capsule with its key beside the icon, and the tool in use fills with the accent color; turn that off with "Show shortcuts in the toolbar" in Settings > Appearance or `"showShortcuts": false`. Every toolbar button and icon-only button has a tooltip with its name and key.
- The first time you use Highlight, Text Box, Sign or Crop, a short tip from its button says what to do next. Settings > General has Show Tips Again.
- With "Show scroll bars" set to Always, Markdown files, images, the outline and the page thumbnails no longer show an empty scroll bar track when there's nothing to scroll; in the Peek panel it sat under the Open in Peeker button.
- The Peek panel remembers its size and position, and opens on the display with the pointer. Its first size is capped at 900 × 700 points, so it's no longer a tall column on a portrait display, and it can't be made smaller than 400 × 300. Settings > General has Reset Panel Size to go back to the default.
- Updates found by the daily check no longer pop up behind your work: the menu bar icon shows a dot and its menu offers "Update to" the new version. Peeker can also download and install updates by itself, relaunching once no window is open: pick Download and Install in Settings > General, or `"updates": {"automatic": "download"}` in the config, which replaces `updates.check`. After an update, a window lists what's new; turn it off with "Show what's new after updating" or `updates.showWhatsNew`.
- Multi-page TIFFs show every page: thumbnails in the sidebar, Next Page and Previous Page in the View menu (Page Down and Page Up), the zoom kept from page to page, and every page printed. The Peek panel still shows the first page. Shortcuts in the config and in Settings can now be `pageup` and `pagedown`.
- Space no longer waits on a busy Finder: if Finder doesn't say what's selected within half a second, the key goes to Finder's Quick Look, and the arrow keys leave the Peek panel as it is.
- Open With in a window lists only the plugins that can show the file: Markdown and Plain Text for a Markdown file, but no longer Image or PDF. When only one can, the toolbar leaves Open With out and File > Open With is greyed out.
- Links in Markdown to other files and to headings work. A heading link scrolls to the heading, a link to another Markdown file opens it in the same tab, and any other file opens in a tab of its own. Back and Forward (Cmd-[ and Cmd-], in the toolbar and in a new Go menu) return to where you were, and a trail under the toolbar lists the places you've been. In the Peek panel, a link to a file opens it in a window.
- The Peek panel and printing show images stored on your Mac in Markdown files; web images still show their alt text, so nothing is fetched.
- Photos stay sharp when zoomed in or at Actual Size.
- PDFs gain Actual Size (Cmd+0) and Zoom to Fit (Cmd+9) in the View menu, as images have. Plain text and Markdown windows gain Actual Size (Cmd+0), which puts the text back at the size it opened at.
- Wrap Lines no longer takes Opt+Cmd+W, the standard key for closing all windows; set a shortcut for it in Settings if you want one. A config saved from Settings keeps Opt+Cmd+W on Wrap Lines until you clear it in Settings > Plain Text.
- The signature pad's line and edge show in dark mode.
- Text boxes and signatures in PDFs stay sharp when zoomed in.
- A PDF text box's size buttons stay in place while you click them.
- Code is colored by its syntax: Python, JavaScript and TypeScript, Swift, C and C++, Go, Rust, Java, Kotlin, Ruby, shell scripts, SQL, CSS, JSON, YAML, TOML and config files, plus code blocks in Markdown tagged with a language. Each text theme has its own code colors, and printing keeps them.
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
