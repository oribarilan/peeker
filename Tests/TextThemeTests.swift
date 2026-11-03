import AppKit
import PeekerKit
import Testing

/// `color` as sRGB in `appearance`, as a hex number.
@MainActor func hex(_ color: NSColor, in appearance: NSAppearance.Name) -> UInt32 {
    var value: UInt32 = 0
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        let rgb = color.usingColorSpace(.sRGB)!
        value = UInt32((rgb.redComponent * 255).rounded()) << 16 | UInt32((rgb.greenComponent * 255).rounded()) << 8 | UInt32((rgb.blueComponent * 255).rounded())
    }
    return value
}

private nonisolated final class Count: @unchecked Sendable { var value = 0 }

@Suite(.serialized) @MainActor struct TextThemes {
    @Test func eightThemesInPopUpOrder() {
        #expect(TextTheme.all.map(\.id) == ["system", "paper", "slate", "graphite", "ink", "catppuccin", "tokyo-night", "high-contrast"])
        #expect(TextTheme.ids == TextTheme.all.map(\.id))
        #expect(TextTheme.all.map(\.name) == ["System", "Paper", "Slate", "Graphite", "Ink", "Catppuccin", "Tokyo Night", "High Contrast"])
        #expect(TextTheme.all.map(\.group) == [0, 1, 1, 1, 1, 2, 2, 3])
    }

    @Test func namedFindsEachIDAndNothingElse() {
        for theme in TextTheme.all { #expect(TextTheme.named(theme.id)?.id == theme.id) }
        #expect(TextTheme.named("tokyonight") == nil)
        #expect(TextTheme.named("") == nil)
    }

    @Test func colorsFollowTheAppearance() {
        let paper = TextTheme.named("paper")!
        #expect(hex(paper.background, in: .aqua) == 0xF7F3EA)
        #expect(hex(paper.background, in: .darkAqua) == 0x23211D)
        let mocha = TextTheme.named("catppuccin")!
        #expect(hex(mocha.background, in: .darkAqua) == 0x1E1E2E)
        #expect(hex(mocha.link, in: .aqua) == 0x1E66F5)
        #expect(hex(TextTheme.system.text, in: .aqua) == hex(.labelColor, in: .aqua))
        #expect(hex(TextTheme.system.background, in: .darkAqua) == hex(.textBackgroundColor, in: .darkAqua))
    }

    @Test func settingTheCurrentThemeTellsTheViews() {
        defer { TextTheme.current = .system }
        let told = Count()
        let observer = NotificationCenter.default.addObserver(forName: TextTheme.didChange, object: nil, queue: nil) { _ in told.value += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }
        TextTheme.current = TextTheme.named("ink")!
        #expect(told.value == 1)
        #expect(TextTheme.current.id == "ink")
        TextTheme.current = TextTheme.named("ink")!
        #expect(told.value == 1, "the same theme again changes nothing")
    }
}
