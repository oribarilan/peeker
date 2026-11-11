import AppKit
import PeekerKit
import Testing

/// `color` as sRGB in `appearance`, as a hex number.
@MainActor func hex(_ color: NSColor, in appearance: NSAppearance.Name) -> UInt32 {
    var value: UInt32 = 0
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
        let rgb = color.usingColorSpace(.sRGB)!
        value =
            UInt32((rgb.redComponent * 255).rounded()) << 16 | UInt32((rgb.greenComponent * 255).rounded()) << 8
            | UInt32((rgb.blueComponent * 255).rounded())
    }
    return value
}

private nonisolated final class Count: @unchecked Sendable { var value = 0 }

/// Every suite that changes the current theme or text appearance nests here, so they run one at a time and none sees
/// another's theme.
@Suite(.serialized) @MainActor struct ThemeState {}

extension ThemeState {
    @Suite struct TextThemes {
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

        @Test func everyThemeHasSixSyntaxColorsInEachLook() {
            func six(_ theme: TextTheme, _ look: NSAppearance.Name) -> [UInt32] {
                let syntax = theme.syntax
                return [syntax.keyword, syntax.string, syntax.comment, syntax.number, syntax.type, syntax.function].map { hex($0, in: look) }
            }
            #expect(six(.system, .aqua) == [0x9B2393, 0xC41A16, 0x5D6C79, 0x1C00CF, 0x0B4F79, 0x326D74], "Xcode's light defaults")
            #expect(six(.system, .darkAqua) == [0xFC5FA3, 0xFC6A5D, 0x7F8C98, 0xD0BF69, 0x5DD8FF, 0x67B7A4], "Xcode's dark defaults")
            #expect(six(TextTheme.named("catppuccin")!, .darkAqua) == [0xCBA6F7, 0xA6E3A1, 0x9399B2, 0xFAB387, 0xF9E2AF, 0x89B4FA], "Mocha")
            #expect(six(TextTheme.named("catppuccin")!, .aqua) == [0x8839EF, 0x40A02B, 0x7C7F93, 0xFE640B, 0xDF8E1D, 0x1E66F5], "Latte")
            #expect(six(TextTheme.named("tokyo-night")!, .darkAqua) == [0xBB9AF7, 0x9ECE6A, 0x565F89, 0xFF9E64, 0x2AC3DE, 0x7AA2F7])
            for theme in TextTheme.all {
                #expect(Set(six(theme, .aqua)).count == 6 && Set(six(theme, .darkAqua)).count == 6, "\(theme.id): six distinct colors")
                #expect(six(theme, .aqua) != six(theme, .darkAqua), "\(theme.id): light and dark differ")
            }
        }

        @Test func settingTheTextAppearanceTellsTheViews() {
            defer { TextTheme.appearance = nil }
            #expect(TextTheme.appearance == nil, "text matches the app by default")
            let told = Count()
            let observer = NotificationCenter.default.addObserver(forName: TextTheme.didChange, object: nil, queue: nil) { _ in told.value += 1 }
            defer { NotificationCenter.default.removeObserver(observer) }
            TextTheme.appearance = NSAppearance(named: .darkAqua)
            #expect(told.value == 1)
            TextTheme.appearance = NSAppearance(named: .darkAqua)
            #expect(told.value == 1, "the same appearance again changes nothing")
            TextTheme.appearance = nil
            #expect(told.value == 2)
        }
    }
}
