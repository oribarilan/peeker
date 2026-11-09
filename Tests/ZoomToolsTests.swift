import PeekerKit
@testable import PeekerData
@testable import PeekerImage
@testable import PeekerMarkdown
@testable import PeekerTable
@testable import PeekerText
import Testing

/// The zoom control's − and + run these tools by id; a format without them would leave the buttons doing nothing.
@Test func everyZoomingFormatHasTheZoomTools() {
    let plugins: [any Plugin.Type] = [TextPlugin.self, MarkdownPlugin.self, ImagePlugin.self, TablePlugin.self, DataPlugin.self]
    for plugin in plugins {
        #expect(Set(plugin.tools.map(\.id)).isSuperset(of: ["zoom-in", "zoom-out", "zoom-actual"]), "\(plugin.name)")
    }
}
