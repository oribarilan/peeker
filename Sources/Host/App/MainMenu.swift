import AppKit

enum MainMenu {
    static func rebuildCommands(_ menu: NSMenu, for controller: DocumentWindowController) {
        menu.removeAllItems()
        for (index, command) in (controller.current?.commands ?? []).enumerated() {
            let item = NSMenuItem(title: command.spec.title, action: #selector(DocumentWindowController.runCommand(_:)), keyEquivalent: command.shortcut?.keyEquivalent ?? "")
            item.keyEquivalentModifierMask = command.shortcut?.modifiers ?? []
            item.tag = index
            item.target = controller
            menu.addItem(item)
        }
    }

    static func make(target: AppDelegate) -> NSMenu {
        let main = NSMenu()
        let commands = NSMenu(title: "Commands")
        func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let menu = NSMenu(title: title)
            items.forEach(menu.addItem)
            main.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
            return menu
        }
        func item(_ title: String, _ action: Selector?, _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command, tag: Int = 0, target: AnyObject? = nil) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.tag = tag
            item.target = target
            return item
        }

        _ = submenu("Preview++", [
            item("About Preview++", #selector(NSApplication.orderFrontStandardAboutPanel(_:))),
            .separator(),
            item("Reload Config", #selector(AppDelegate.reloadConfig(_:)), "r", [.command, .shift], target: target),
            item("Open at Login", #selector(AppDelegate.toggleOpenAtLogin(_:)), target: target),
            .separator(),
            item("Hide Preview++", #selector(NSApplication.hide(_:)), "h"),
            item("Quit Preview++", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = submenu("File", [
            item("Open…", #selector(AppDelegate.showOpenPanel(_:)), "o", target: target),
            item("Close", #selector(NSWindow.performClose(_:)), "w"),
            item("Save", #selector(DocumentWindowController.saveDocument(_:)), "s"),
        ])
        _ = submenu("Edit", [
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
        ])
        main.addItem(withTitle: "Commands", action: nil, keyEquivalent: "").submenu = commands
        NSApp.windowsMenu = submenu("Window", [
            item("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("Show Previous Tab", #selector(NSWindow.selectPreviousTab(_:)), "{"),
            item("Show Next Tab", #selector(NSWindow.selectNextTab(_:)), "}"),
        ])
        return main
    }
}
