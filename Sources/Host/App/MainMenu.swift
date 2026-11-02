import AppKit

enum MainMenu {
    /// Marks the separator put before a document's commands, so a rebuild removes only what it added: AppKit adds
    /// items of its own to View (Show Tab Bar, Show All Tabs).
    private static let commandsSeparatorTag = -1

    /// Puts the document's commands into View (zoom, wrap and other view commands) and Tools (edit tools), replacing
    /// the last document's. Nil, when no document window is in front, leaves only the fixed items.
    static func rebuildCommands(view: NSMenu, tools: NSMenu, for controller: DocumentWindowController?) {
        for menu in [view, tools] {
            for item in menu.items where item.action == #selector(DocumentWindowController.runCommand(_:))
                || (item.isSeparatorItem && item.tag == commandsSeparatorTag) {
                menu.removeItem(item)
            }
        }
        // Edit Mode goes straight to the window, like the commands, rather than through the responder chain, which
        // can miss the window right after it opens.
        tools.items.first { $0.action == #selector(DocumentWindowController.toggleEditMode(_:)) }?.target = controller
        guard let controller else { return }
        for (index, command) in (controller.current?.commands ?? []).enumerated() {
            // A single key would swallow that letter in text fields as a menu key equivalent, so the window runs it
            // instead (in Edit mode only) and the title shows it.
            let single = command.shortcut.flatMap { $0.isSingleKey ? $0 : nil }
            let title = single.map { "\(command.spec.title) (\($0.displayText))" } ?? command.spec.title
            let item = NSMenuItem(title: title, action: #selector(DocumentWindowController.runCommand(_:)), keyEquivalent: single == nil ? command.shortcut?.keyEquivalent ?? "" : "")
            item.keyEquivalentModifierMask = single == nil ? command.shortcut?.modifiers ?? [] : []
            item.tag = index
            item.target = controller
            let menu = command.spec.isEditTool ? tools : view
            if menu.items.last?.action != #selector(DocumentWindowController.runCommand(_:)) {
                let separator = NSMenuItem.separator()
                separator.tag = commandsSeparatorTag
                menu.addItem(separator)
            }
            menu.addItem(item)
        }
    }

    /// The keys the menu bar's own items use, which no plugin command may take: everything but plugin commands.
    static let fixedShortcuts = menuShortcuts(in: make(target: nil))

    /// The whole menu bar. The app makes Window its windows menu and Help its help menu; building it changes nothing else.
    static func make(target: AppDelegate?) -> NSMenu {
        let main = NSMenu()
        func submenu(_ title: String, _ items: [NSMenuItem]) {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            main.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
        }
        func item(_ title: String, _ action: Selector?, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command, tag: Int = 0, target: AnyObject? = nil) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.tag = tag
            item.target = target
            return item
        }

        func submenuItem(_ title: String, _ action: Selector? = nil) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.submenu = NSMenu(title: title)
            return item
        }

        submenu("Peeker", [
            item("About Peeker", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            item("Check for Updates…", #selector(AppDelegate.checkForUpdates(_:)), "", [], target: target),
            item("Settings…", #selector(AppDelegate.showSettings(_:)), ",", target: target),
            .separator(),
            item("Hide Peeker", #selector(NSApplication.hide(_:)), "h"),
            item("Hide Others", #selector(NSApplication.hideOtherApplications(_:)), "h", [.option, .command]),
            item("Show All", #selector(NSApplication.unhideAllApplications(_:)), "", []),
            .separator(),
            item("Quit Peeker", #selector(NSApplication.terminate(_:)), "q"),
        ])
        submenu("File", [
            item("Open…", #selector(AppDelegate.showOpenPanel(_:)), "o", target: target),
            submenuItem("Open Recent"),
            // Only a document window answers this, so the submenu is greyed out elsewhere; the window fills it.
            submenuItem("Open With", #selector(DocumentWindowController.reopenWithMenu(_:))),
            .separator(),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Save", #selector(DocumentWindowController.saveDocument(_:)), "s"),
            item("Revert to Saved…", #selector(DocumentWindowController.revertDocument(_:))),
            .separator(),
            item("Print…", #selector(DocumentWindowController.printDocument(_:)), "p"),
        ])
        submenu("Edit", [
            item("Undo", Selector(("undo:")), "z"),
            item("Redo", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("Cut", #selector(NSText.cut(_:)), "x"),
            item("Copy", #selector(NSText.copy(_:)), "c"),
            item("Paste", #selector(NSText.paste(_:)), "v"),
            item("Select All", #selector(NSText.selectAll(_:)), "a"),
            .separator(),
            item("Find…", #selector(NSTextView.performFindPanelAction(_:)), "f", tag: Int(NSFindPanelAction.showFindPanel.rawValue)),
            item("Find Next", #selector(NSTextView.performFindPanelAction(_:)), "g", tag: Int(NSFindPanelAction.next.rawValue)),
            item("Find Previous", #selector(NSTextView.performFindPanelAction(_:)), "g", [.command, .shift], tag: Int(NSFindPanelAction.previous.rawValue)),
        ])
        // AppKit retitles these three (Show/Hide, Enter/Exit) as their state changes.
        submenu("View", [
            item("Show Sidebar", #selector(NSSplitViewController.toggleSidebar(_:)), "s", [.control, .command]),
            item("Show Toolbar", #selector(NSWindow.toggleToolbarShown(_:)), "t", [.option, .command]),
            item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.control, .command]),
        ])
        submenu("Tools", [
            item("Edit Mode", #selector(DocumentWindowController.toggleEditMode(_:)), Shortcut.editMode.keyEquivalent, Shortcut.editMode.modifiers),
        ])
        submenu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Zoom", #selector(NSWindow.performZoom(_:))),
            item("Show Previous Tab", #selector(NSWindow.selectPreviousTab(_:)), "{"),
            item("Show Next Tab", #selector(NSWindow.selectNextTab(_:)), "}"),
            .separator(),
            item("Bring All to Front", #selector(NSApplication.arrangeInFront(_:))),
        ])
        submenu("Help", [
            item("Peeker Help", #selector(AppDelegate.showHelp(_:)), "?", target: target),
        ])
        return main
    }
}
