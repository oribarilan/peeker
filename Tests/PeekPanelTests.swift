import AppKit
import Testing

@Suite(.serialized) struct PeekPanelButton {
    /// The name tells the panel apart from Quick Look, whose button opens Preview.
    @Test func theButtonReadsOpenInPeeker() {
        let panel = PeekPanel()
        defer { panel.close() }
        #expect(panel.openButton.title == "Open in Peeker")
    }
}
