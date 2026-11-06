import AppKit
import PeekerKit

enum MainMenu {
    /// Marks the separator put before a document's view tools, so a rebuild removes only what it added: AppKit adds
    /// items of its own to View (Show Tab Bar, Show All Tabs).
    private static let toolsSeparatorTag = -1
    /// Marks Tools' greyed-out No Tools item.
    private static let noToolsTag = -2
    /// The item holding a tool's choices, removed with the tools.
    private static let choicesTag = -3

    /// Puts the document's tools into View (zoom, wrap and other view tools) and Tools (edit tools), replacing the
    /// last document's. Nil, when no Editor window is in front, leaves only the fixed items. Tools without edit tools
    /// shows No Tools, greyed out, so the menu bar stays the same.
    static func rebuildTools(view: NSMenu, tools: NSMenu, file: NSMenu? = nil, for controller: DocumentWindowController?) {
        for menu in [view, tools] + (file.map { [$0] } ?? []) {
            for item in menu.items where item.action == #selector(DocumentWindowController.runTool(_:))
                || (item.isSeparatorItem && item.tag == toolsSeparatorTag) || item.tag == noToolsTag || item.tag == choicesTag {
                menu.removeItem(item)
            }
        }
        defer { if tools.items.isEmpty { tools.addItem(noToolsItem()) } }
        guard let controller else { return }
        for (index, tool) in (controller.current?.tools ?? []).enumerated() {
            // A single key would swallow that letter in text fields as a menu key equivalent, so the window runs it
            // instead and the title shows it.
            let single = tool.shortcut.flatMap { $0.isSingleKey ? $0 : nil }
            let title = single.map { "\(tool.spec.title) (\($0.displayText))" } ?? tool.spec.title
            let item = NSMenuItem(title: title, action: #selector(DocumentWindowController.runTool(_:)), keyEquivalent: single == nil ? tool.shortcut?.keyEquivalent ?? "" : "")
            item.keyEquivalentModifierMask = single == nil ? tool.shortcut?.modifiers ?? [] : []
            item.tag = index
            item.target = controller
            if tool.spec.menu == .file {
                // After Save As… and the file tools before it.
                guard let file, let saveAs = file.items.firstIndex(where: { $0.action == #selector(DocumentWindowController.saveDocumentAs(_:)) })
                else { continue }
                let after = file.items[(saveAs + 1)...].prefix { $0.action == #selector(DocumentWindowController.runTool(_:)) }.count
                file.insertItem(item, at: saveAs + 1 + after)
                continue
            }
            let menu = tool.spec.menu == .tools ? tools : view
            if !menu.items.isEmpty, menu.items.last?.action != #selector(DocumentWindowController.runTool(_:)), menu.items.last?.tag != choicesTag {
                let separator = NSMenuItem.separator()
                separator.tag = toolsSeparatorTag
                menu.addItem(separator)
            }
            menu.addItem(item)
            if !tool.spec.choices.isEmpty, let title = tool.spec.choicesTitle {
                let choices = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                choices.tag = choicesTag
                choices.submenu = choiceMenu(for: tool.spec, at: index, target: controller)
                menu.addItem(choices)
            }
        }
    }

    /// A tool's choices, each with a dot in its color, run by `DocumentWindowController.runChoice(_:)`. Also the menu
    /// of the tool's toolbar button, which draws no item images, hence the dot in the title.
    static func choiceMenu(for spec: ToolSpec, at index: Int, target: AnyObject?) -> NSMenu {
        let menu = NSMenu(title: spec.choicesTitle ?? spec.title)
        for choice in spec.choices {
            let item = NSMenuItem(title: choice.title, action: #selector(DocumentWindowController.runChoice(_:)), keyEquivalent: "")
            item.target = target
            item.tag = index
            item.representedObject = choice.id
            if let color = choice.color.flatMap({ NSColor(cgColor: $0.cgColor) }) {
                let font = NSFont.menuFont(ofSize: 0)
                let title = NSMutableAttributedString(string: "●  ", attributes: [.foregroundColor: color, .font: font])
                title.append(NSAttributedString(string: choice.title, attributes: [.font: font]))
                item.attributedTitle = title
                item.setAccessibilityLabel(choice.title)
            }
            menu.addItem(item)
        }
        return menu
    }

    /// No action, so AppKit greys it out.
    private static func noToolsItem() -> NSMenuItem {
        let item = NSMenuItem(title: "No Tools", action: nil, keyEquivalent: "")
        item.tag = noToolsTag
        return item
    }

    /// The keys the menu bar's own items use, which no plugin tool may take: everything but plugin tools.
    static let fixedShortcuts = menuShortcuts(in: make(target: nil))

    /// Keys the toolbar shows for its own buttons too, so the menu and the captions can't disagree.
    static let sidebarKey = Shortcut(key: .character("s"), modifiers: [.control, .command])
    static let backKey = Shortcut(key: .character("["), modifiers: .command)
    static let forwardKey = Shortcut(key: .character("]"), modifiers: .command)

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
            // Only an Editor window answers this, so the submenu is greyed out elsewhere; the window fills it.
            submenuItem("Open With", #selector(DocumentWindowController.reopenWithMenu(_:))),
            .separator(),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Save", #selector(DocumentWindowController.saveDocument(_:)), "s"),
            item("Save As…", #selector(DocumentWindowController.saveDocumentAs(_:)), "s", [.command, .shift]),
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
            item("Show Sidebar", #selector(NSSplitViewController.toggleSidebar(_:)), sidebarKey.keyEquivalent, sidebarKey.modifiers),
            item("Show Toolbar", #selector(NSWindow.toggleToolbarShown(_:)), "t", [.option, .command]),
            item("Enter Full Screen", #selector(NSWindow.toggleFullScreen(_:)), "f", [.control, .command]),
        ])
        // Where Preview and Finder keep them. Only an Editor window answers, so they're greyed out elsewhere.
        submenu("Go", [
            item("Back", #selector(DocumentWindowController.goBack(_:)), backKey.keyEquivalent, backKey.modifiers),
            item("Forward", #selector(DocumentWindowController.goForward(_:)), forwardKey.keyEquivalent, forwardKey.modifiers),
        ])
        submenu("Tools", [noToolsItem()])
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
