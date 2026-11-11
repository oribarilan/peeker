import AppKit
import os

/// Reads Finder's selection over Apple Events (needs the Automation permission for Finder), giving up after `timeout`
/// so a busy or hung Finder can't hold up Space or the main thread for longer.
final class FinderBridge {
    private let target: String
    private let timeout: TimeInterval
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.peeker", category: "peekpanel")

    init(target: String = "com.apple.finder", timeout: TimeInterval = 0.5) {
        self.target = target
        self.timeout = timeout
    }

    /// The selected files, or none when Finder doesn't answer in time, refuses, or has nothing selected.
    func selection() -> [URL] {
        do {
            return Self.urls(from: try selectionEvent().sendEvent(options: .waitForReply, timeout: timeout))
        } catch {
            Self.log.warning("finder: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    /// The file URLs in a reply's list, in order.
    static func urls(from reply: NSAppleEventDescriptor) -> [URL] {
        guard let list = reply.paramDescriptor(forKeyword: keyDirectObject), list.numberOfItems > 0 else { return [] }
        return (1...list.numberOfItems).compactMap { list.atIndex($0)?.fileURLValue }
    }

    /// The AppleScript `get selection as alias list`, sent to Finder as one get-data event.
    private func selectionEvent() -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: kAECoreSuite, eventID: kAEGetData,
            targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: target),
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        // An object specifier for the application's `selection` property.
        let selection = NSAppleEventDescriptor.record().coerce(toDescriptorType: typeObjectSpecifier) ?? .record()
        selection.setDescriptor(NSAppleEventDescriptor(typeCode: typeProperty), forKeyword: AEKeyword(keyAEDesiredClass))
        selection.setDescriptor(NSAppleEventDescriptor(enumCode: OSType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        selection.setDescriptor(NSAppleEventDescriptor(typeCode: OSType(pSelection)), forKeyword: AEKeyword(keyAEKeyData))
        selection.setDescriptor(.null(), forKeyword: AEKeyword(keyAEContainer))
        event.setParam(selection, forKeyword: keyDirectObject)
        event.setParam(NSAppleEventDescriptor(typeCode: Self.aliasList), forKeyword: keyAERequestedType)
        return event
    }

    /// AppleScript's `alias list` class.
    private static let aliasList: DescType = 0x616C_7374  // 'alst'
}
