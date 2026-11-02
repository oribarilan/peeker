import AppKit
import PeekerKit
@testable import PeekerText
import Testing

@Suite(.serialized) struct DocumentWindowSize {
    @Test func aWindowCantShrinkBelowItsMinimum() async throws {
        let controller = try await documentWindow(for: TextPlugin.self, name: "f.txt")
        defer { controller.close() }
        #expect(controller.window?.contentMinSize == NSSize(width: 480, height: 320))
    }
}
