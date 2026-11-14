import AppKit
import UniformTypeIdentifiers

/// An installed app a file can be opened with.
nonisolated struct AppChoice: Equatable, Sendable {
    let bundleID: String
    let name: String
    let url: URL

    init(bundleID: String, name: String, url: URL) {
        self.bundleID = bundleID
        self.name = name
        self.url = url
    }

    /// The app at `url`; nil when it has no bundle ID.
    init?(url: URL) {
        guard let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        let name = FileManager.default.displayName(atPath: url.path)
        self.init(bundleID: id, name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name, url: url)
    }

    static func installed(bundleID: String) -> AppChoice? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID).flatMap(AppChoice.init(url:))
    }
}

/// The other apps that open a file, for the Peek panel's button and the Editor's File > Open With: listing them,
/// ordering them, opening the file in one, and Other…'s picker of any app.
nonisolated enum AppChoices {
    /// The apps macOS says open `url`.
    static func list(for url: URL) -> [AppChoice] {
        NSWorkspace.shared.urlsForApplications(toOpen: url).compactMap(AppChoice.init(url:))
    }

    /// The bundle ID of the Mac's default app for `url`.
    static func systemDefault(for url: URL) -> String? {
        NSWorkspace.shared.urlForApplication(toOpen: url).flatMap { Bundle(url: $0)?.bundleIdentifier }
    }

    /// `apps` without the `excluded` bundle IDs or a second copy of one, the Mac's default first, then A to Z.
    static func sorted(_ apps: [AppChoice], systemDefault: String?, excluding excluded: Set<String>) -> [AppChoice] {
        var seen = excluded
        return apps.filter { seen.insert($0.bundleID).inserted }.sorted { a, b in
            if (a.bundleID == systemDefault) != (b.bundleID == systemDefault) { return a.bundleID == systemDefault }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    /// Opens `file` in the app at `app`, in front.
    static func open(_ file: URL, in app: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([file], withApplicationAt: app, configuration: configuration)
    }

    /// Other…: a picker of apps in `/Applications` as a sheet on `window`, with a checkbox titled `always` when it's
    /// given. `completion` gets the chosen app (nil on Cancel) and whether the checkbox was ticked.
    @MainActor static func pickOther(for url: URL, on window: NSWindow, always: String?, completion: @escaping (URL?, Bool) -> Void) {
        let picker = NSOpenPanel()
        picker.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        picker.allowedContentTypes = [.application]
        picker.treatsFilePackagesAsDirectories = false
        picker.message = "Choose an app to open “\(url.lastPathComponent)”."
        picker.prompt = "Open"
        var box: NSButton?
        if let always {
            let checkbox = NSButton(checkboxWithTitle: always, target: nil, action: nil)
            checkbox.sizeToFit()
            let holder = NSView(frame: NSRect(x: 0, y: 0, width: checkbox.frame.width + 40, height: checkbox.frame.height + 16))
            checkbox.frame.origin = NSPoint(x: 20, y: 8)
            holder.addSubview(checkbox)
            picker.accessoryView = holder
            picker.isAccessoryViewDisclosed = true
            box = checkbox
        }
        picker.beginSheetModal(for: window) { response in
            completion(response == .OK ? picker.url : nil, box?.state == .on)
        }
    }
}
