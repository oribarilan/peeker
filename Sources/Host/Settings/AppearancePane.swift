import AppKit
import PeekerKit
import SwiftUI

/// The app's appearance, the text appearance, and the text theme as a grid of preview cards.
struct AppearancePane: View {
    @Bindable var model: SettingsModel
    @Environment(\.colorScheme) private var scheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        Form {
            ConfigLockedSection(store: model.store)
            Section {
                Picker("Appearance", selection: $model.appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Picker("Text appearance", selection: $model.textAppearance) {
                    Text("Match App").tag("app")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
            } footer: {
                Text("Text appearance picks the light or dark look of the text theme, so a page can stay light in a dark app.")
                    .foregroundStyle(.secondary)
            }
            .pickerStyle(.segmented)
            .disabled(!model.store.isUsable)
            Section {
                LazyVGrid(columns: columns, spacing: 12) {
                    let dark = ThemeCard.isDark(textAppearance: model.textAppearance, appIsDark: scheme == .dark)
                    ForEach(TextTheme.all, id: \.id) { theme in
                        ThemeCard(theme: theme, dark: dark, selected: theme.id == model.textTheme) { model.textTheme = theme.id }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Text theme")
            } footer: {
                Text("The colors of Markdown and text files, in windows and the Peek panel. Printing stays black on white.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!model.store.isUsable)
        }
        .formStyle(.grouped)
    }
}

/// One theme's card: a few lines of styled Markdown source in the theme's colors, with its name under it.
struct ThemeCard: View {
    let theme: TextTheme
    let dark: Bool
    let selected: Bool
    let choose: () -> Void

    /// Whether cards draw the dark variant: the text appearance, or for Match App the pane's own look.
    static func isDark(textAppearance: String, appIsDark: Bool) -> Bool {
        textAppearance == "app" ? appIsDark : textAppearance == "dark"
    }

    /// `color` fixed to its light or dark value, so the card doesn't depend on the appearance it's drawn in.
    static func resolve(_ color: NSColor, dark: Bool) -> NSColor {
        var resolved = color
        NSAppearance(named: dark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB) ?? color
        }
        return resolved
    }

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(run("# ", theme.marker, size: 13) + run("Title", theme.heading, size: 13, weight: .bold))
                    Text(run("See ", theme.text) + run("the docs", theme.link) + run(".", theme.text))
                    Text(run("Run ", theme.text) + run("`", theme.marker) + run("make", theme.text, mono: true, background: theme.codeBackground)
                         + run("`", theme.marker))
                    Text(run("- [x] ", theme.marker) + run("Done", theme.text))
                }
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(color(theme.background), in: .rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 2.5 : 1)
                }
                Text(theme.name)
                    .font(.callout)
                    .lineLimit(1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)  // the name alone, not the sample's text
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func color(_ color: NSColor) -> Color { Color(nsColor: Self.resolve(color, dark: dark)) }

    private func run(_ text: String, _ foreground: NSColor, size: CGFloat = 11, weight: Font.Weight = .regular, mono: Bool = false,
                     background: NSColor? = nil) -> AttributedString {
        var run = AttributedString(text)
        run.foregroundColor = color(foreground)
        run.font = .system(size: size, weight: weight, design: mono ? .monospaced : .default)
        if let background { run.backgroundColor = color(background) }
        return run
    }
}
