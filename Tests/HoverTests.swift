import AppKit
import PeekerKit
import Testing

/// `color` resolved for the light or dark appearance, in sRGB.
@MainActor private func resolved(_ color: NSColor, dark: Bool) -> NSColor? {
    var result: NSColor?
    NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
        result = color.usingColorSpace(.sRGB)
    }
    return result
}

@MainActor @Suite(.serialized) struct HoverLook {
    @Test func theTintIsTheAccentFainterInLightThanInDark() throws {
        let light = try #require(resolved(HoverStyle.color, dark: false))
        let dark = try #require(resolved(HoverStyle.color, dark: true))
        #expect(abs(light.alphaComponent - 0.12) < 0.001)
        #expect(abs(dark.alphaComponent - 0.18) < 0.001)
        let accent = try #require(resolved(.controlAccentColor, dark: false))
        #expect(abs(light.redComponent - accent.redComponent) < 0.01 && abs(light.blueComponent - accent.blueComponent) < 0.01)
    }

    @Test func reduceMotionTakesTheFadeAway() {
        defer { HoverStyle.reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion } }
        HoverStyle.reducesMotion = { false }
        #expect(HoverStyle.fade > 0)
        HoverStyle.reducesMotion = { true }
        #expect(HoverStyle.fade == 0)
    }

    @Test func theFillShowsOnlyWhileHovered() {
        let fill = HoverFill(frame: NSRect(x: 0, y: 0, width: 40, height: 20))
        let window = offscreenWindow(holding: fill)
        defer { window.close() }
        #expect(fill.alphaValue == 0, "hidden at first")
        fill.isHovered = true
        #expect(fill.alphaValue == 1)
        fill.isHovered = false
        #expect(fill.alphaValue == 0)
        #expect(fill.hitTest(NSPoint(x: 10, y: 10)) == nil, "clicks go through to what's under it")
    }

    @Test func aRowShowsTheFillWhileHoveredButNotWhileSelected() {
        let row = HoverRowView()
        row.isHovered = true
        #expect(row.hoverFill.isHovered)
        row.isSelected = true
        #expect(!row.hoverFill.isHovered, "a selected row keeps its own look")
        row.isSelected = false
        #expect(row.hoverFill.isHovered)
        row.isHovered = false
        #expect(!row.hoverFill.isHovered)
    }
}
