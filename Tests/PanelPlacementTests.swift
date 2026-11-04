import AppKit
import Testing

@Suite struct PanelPlacementRules {
    private let portrait = NSRect(x: 0, y: 0, width: 1440, height: 2560)
    private let laptop = NSRect(x: 0, y: 0, width: 1280, height: 800)

    private func centered(_ size: NSSize, on screen: NSRect) -> NSRect {
        NSRect(x: (screen.midX - size.width / 2).rounded(.down), y: (screen.midY - size.height / 2).rounded(.down),
               width: size.width, height: size.height)
    }

    @Test func withNothingSavedItOpensAtTheCappedDefaultCentered() {
        #expect(PanelPlacement.frame(saved: nil, screen: portrait) == centered(NSSize(width: 792, height: 700), on: portrait))
        #expect(PanelPlacement.frame(saved: nil, screen: laptop) == centered(NSSize(width: 704, height: 600), on: laptop))
    }

    @Test func theDefaultNeverGoesBelowTheMinimum() {
        let tiny = NSRect(x: 0, y: 0, width: 600, height: 400)
        #expect(PanelPlacement.frame(saved: nil, screen: tiny).size == PanelPlacement.minimumSize)
        #expect(PanelPlacement.minimumSize == NSSize(width: 400, height: 300))
    }

    @Test func aSavedFrameOnThisDisplayComesBackAsIs() {
        let saved = NSRect(x: 40, y: 1800, width: 600, height: 500)
        #expect(PanelPlacement.frame(saved: saved, screen: portrait) == saved)
    }

    @Test func aSavedFrameOnAnotherDisplayKeepsItsSizeCenteredHere() {
        let saved = NSRect(x: 1600, y: 100, width: 600, height: 500)  // on a display to the right
        #expect(PanelPlacement.frame(saved: saved, screen: laptop) == centered(NSSize(width: 600, height: 500), on: laptop))
    }

    @Test func aSavedFrameTooBigForThisDisplayGivesTheDefault() {
        let saved = NSRect(x: 1600, y: 0, width: 1400, height: 1000)
        #expect(PanelPlacement.frame(saved: saved, screen: laptop) == centered(NSSize(width: 704, height: 600), on: laptop))
    }

    @Test func aSavedFrameHalfOffThisDisplayCountsAsOutside() {
        let saved = NSRect(x: 1000, y: 100, width: 600, height: 500)  // sticks out past the right edge
        #expect(PanelPlacement.frame(saved: saved, screen: laptop) == centered(NSSize(width: 600, height: 500), on: laptop))
    }

    @Test func aSavedFrameSmallerThanTheMinimumIsIgnored() {
        // What NSRectFromString gives for an unreadable preference.
        #expect(PanelPlacement.frame(saved: .zero, screen: laptop) == centered(NSSize(width: 704, height: 600), on: laptop))
        let tooSmall = NSRect(x: 10, y: 10, width: 200, height: 100)
        #expect(PanelPlacement.frame(saved: tooSmall, screen: laptop) == centered(NSSize(width: 704, height: 600), on: laptop))
    }

    @Test func itCentersOnWholePoints() {
        // An odd difference between screen and panel, as on CI's display, would put the panel on a half point.
        let odd = NSRect(x: 0, y: 0, width: 1024, height: 675)
        let frame = PanelPlacement.frame(saved: NSRect(x: 2000, y: 0, width: 563, height: 506), screen: odd)
        #expect(frame.origin.x == frame.origin.x.rounded() && frame.origin.y == frame.origin.y.rounded())
    }
}
