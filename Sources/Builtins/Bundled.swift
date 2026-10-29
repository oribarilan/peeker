import PreviewPPKit

/// "All bundled": every first-party plugin is compiled into the app.
func registerBuiltins(in registry: PluginRegistry) {
    registry.register(TextPlugin.self, runtime: .builtin)
    registry.register(MarkdownPlugin.self, runtime: .builtin)
    registry.register(PDFPlugin.self, runtime: .builtin)
    registry.register(CSVPlugin.self, runtime: .builtin)
}
