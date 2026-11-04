import AppKit
import Testing

@Suite(.serialized) struct PeekPanelButton {
    /// The name tells the panel apart from Quick Look, whose button opens Preview.
    @Test func theButtonReadsOpenInPeeker() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        #expect(panel.openButton.title == "Open in Peeker")
    }
}

@Suite(.serialized) struct PeekPanelFrame {
    @Test func itCantBeMadeSmallerThan400By300() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        #expect(panel.minSize == NSSize(width: 400, height: 300))
    }

    @Test func aFrameTheUserGivesItIsSavedButItsOwnPlacementIsNot() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        panel.placeOnScreen()
        #expect(defaults.string(forKey: PeekPanel.frameKey) == nil, "placing itself isn't the user's choice")
        let chosen = NSRect(x: 60, y: 80, width: 600, height: 500)
        panel.setFrame(chosen, display: false)  // as a drag or a resize would
        #expect(defaults.string(forKey: PeekPanel.frameKey) == NSStringFromRect(chosen))
        #expect(PeekPanel.hasSavedFrame(in: defaults))
    }

    @Test func aNewPanelOpensAtTheSavedFrame() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let screen = PeekPanel.pointerScreenFrame()
        let saved = NSRect(x: screen.minX + 20, y: screen.minY + 20, width: 600, height: 500)
        defaults.set(NSStringFromRect(saved), forKey: PeekPanel.frameKey)
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        panel.placeOnScreen()
        #expect(panel.frame == saved)
    }

    @Test func resetForgetsTheFrameAndGoesBackToTheDefault() {
        let (defaults, name) = scratchDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let panel = PeekPanel(defaults: defaults)
        defer { panel.close() }
        panel.setFrame(NSRect(x: 60, y: 80, width: 600, height: 500), display: false)
        panel.resetFrame()
        #expect(!PeekPanel.hasSavedFrame(in: defaults))
        #expect(panel.frame == PanelPlacement.frame(saved: nil, screen: PeekPanel.pointerScreenFrame()))
    }
}
