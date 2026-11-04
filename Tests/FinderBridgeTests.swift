import AppKit
import Testing

@Suite struct FinderBridgeTests {
    private func reply(_ list: NSAppleEventDescriptor?) -> NSAppleEventDescriptor {
        let reply = NSAppleEventDescriptor.record()
        if let list { reply.setDescriptor(list, forKeyword: keyDirectObject) }
        return reply
    }

    @Test func aReplyListBecomesFileURLsInOrder() {
        let list = NSAppleEventDescriptor.list()
        for (index, path) in ["/tmp/a.md", "/tmp/b c.png"].enumerated() {
            list.insert(NSAppleEventDescriptor(fileURL: URL(filePath: path)), at: index + 1)
        }
        #expect(FinderBridge.urls(from: reply(list)).map(\.path) == ["/tmp/a.md", "/tmp/b c.png"])
    }

    @Test func anEmptyOrMissingReplyIsNoSelection() {
        #expect(FinderBridge.urls(from: reply(.list())).isEmpty)
        #expect(FinderBridge.urls(from: reply(nil)).isEmpty)
    }

    @Test func anAppThatIsntRunningAnswersAtOnceWithNothing() {
        let bridge = FinderBridge(target: "dev.peeker.tests.no-such-app", timeout: 2)
        let start = Date()
        #expect(bridge.selection().isEmpty)
        #expect(Date().timeIntervalSince(start) < 1)
    }
}
