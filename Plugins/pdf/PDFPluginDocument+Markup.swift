import AppKit
import PDFKit
import PeekerKit

/// Markup in a PDF: the strip, its tools, and the color and size the next drawing gets.
extension PDFPluginDocument {
    /// Markup's key or button: shows the strip, or hides it and puts down the armed tool.
    func toggleMarkup() {
        let controller = prepareEditing()
        isMarkingUp.toggle()
        if !isMarkingUp { controller?.end() }  // puts down the tool and the selection, so the strip goes too
        showMarkupStrip()
        onActiveToolChange?()
    }

    /// A strip tool, by id, from its key, the Tools menu or the strip: turns Markup on and arms it.
    func armMarkupTool(_ id: String) {
        guard let controller = prepareEditing(), let entry = PDFPlugin.markupTools.first(where: { $0.id == id }) else { return }
        isMarkingUp = true
        if let shape = entry.shape { controller.arm(shape) } else { controller.chooseTextBox() }
    }

    /// The strip under the toolbar while Markup is on, or a mark is typed in or selected, showing its style.
    func showMarkupStrip() {
        // Only where the pages sit in their container: making it here would take the view from wherever it's shown.
        guard let container = pdfView.superview as? PDFFindContainer else { return }
        let state = editController?.stripState
        let made = container.strip == nil
        guard let strip = container.showStrip(isMarkingUp || state != nil) else { return }
        if made {
            strip.onTool = { [weak self] id in
                if let id { self?.armMarkupTool(id) } else { self?.editController?.end() }
            }
            strip.onColor = { [weak self] color in self?.stripPicked(color: color) }
            strip.onSize = { [weak self] size in
                guard let self, let controller = editController else { return }
                var color = markupColor
                if case .drawing(let shown, _)? = controller.stripState { color = shown }  // the selected drawing's
                controller.applyDrawingLook(color: color, size: size)
            }
            strip.onText = { [weak self] style, size in self?.editController?.applyTextBoxStyle(style, size: size) }
            strip.pages = pdfView
        }
        strip.show(tool: armedToolID, state: state ?? .drawing(markupColor, markupSize))
    }

    /// The armed strip tool's id, which the strip shows selected and the Tools menu checks.
    var armedToolID: String? {
        switch editController?.tool ?? .none {
        case .textBox: PDFPlugin.markupTools.first { $0.shape == nil }?.id
        case .draw(let shape): PDFPlugin.markupTools.first { $0.shape == shape }?.id
        default: nil
        }
    }

    /// A swatch recolors text while the strip shows text, and the drawing otherwise.
    private func stripPicked(color: RGBA) {
        guard let controller = editController else { return }
        if case .text(var style, let size)? = controller.stripState {
            style.color = color
            controller.applyTextBoxStyle(style, size: size)
        } else {
            var size = markupSize
            if case .drawing(_, let shown)? = controller.stripState { size = shown }
            controller.applyDrawingLook(color: color, size: size)
        }
    }

    /// The strip, for tests; nil while hidden.
    var markupStrip: PDFMarkupStrip? { (pdfView.superview as? PDFFindContainer)?.strip.flatMap { $0.isHidden ? nil : $0 } }

    /// The color and size the next drawing gets, read from the app's preferences each time, so a change in another
    /// window counts here too.
    var markupColor: RGBA {
        guard let preferences else { return unrememberedMarkup.color }
        return preferences.string("markupColor").flatMap { try? JSONDecoder().decode(RGBA.self, from: Data($0.utf8)) }
            .flatMap { $0.isValid && $0.alpha == 1 ? $0 : nil } ?? PDFMarkupStrip.palette[0].color
    }

    var markupSize: MarkupSize {
        guard let preferences else { return unrememberedMarkup.size }
        return preferences.string("markupSize").flatMap(MarkupSize.init(rawValue:)) ?? .medium
    }

    func rememberMarkup(color: RGBA, size: MarkupSize) {
        unrememberedMarkup = (color, size)
        if let json = try? JSONEncoder().encode(color) { preferences?.set(String(decoding: json, as: UTF8.self), for: "markupColor") }
        preferences?.set(size.rawValue, for: "markupSize")
    }

    // MARK: Copy and Paste

    static let markPasteboardType = NSPasteboard.PasteboardType("dev.peeker.pdf-mark")

    /// Copies the selected text box, drawing or stamp; false when no mark is selected, so the text is copied instead.
    /// A signature or highlight is selected but never copied: a signature on the pasteboard could reach a clipboard
    /// history, and a highlight belongs to its text.
    func copyMark() -> Bool {
        guard let controller = editController, let annotation = controller.selectedAnnotation, let page = annotation.page,
              let index = pdfView.document?.index(for: page) else { return false }
        guard let mark = PDFMarks.mark(of: annotation, page: index), mark.type == .textBox || mark.type == .drawing,
              let data = try? JSONEncoder().encode(mark) else {
            NSSound.beep()
            return true
        }
        pasteboard.clearContents()
        pasteboard.setData(data, forType: Self.markPasteboardType)
        return true
    }

    var canPasteMark: Bool { isEditing && pasteboard.availableType(from: [Self.markPasteboardType]) != nil }

    /// The copied mark on the page in view, a little below and right of where it was and kept on the page, selected.
    /// What comes off the pasteboard is checked as a saved edit would be.
    func pasteMark() -> Bool {
        guard canPasteMark, let data = pasteboard.data(forType: Self.markPasteboardType),
              let copied = try? JSONDecoder().decode(PDFMark.self, from: data), copied.type == .textBox || copied.type == .drawing,
              let controller = prepareEditing(), let document = pdfView.document,
              let page = pdfView.currentPage ?? document.page(at: 0) else { return false }
        let index = document.index(for: page)
        // No bigger than the page: what's on the pasteboard may come from another app.
        let box = page.bounds(for: .mediaBox)
        let size = CGSize(width: min(copied.rect.width, box.width), height: min(copied.rect.height, box.height))
        let rect = EditController.kept(CGRect(origin: copied.rect.offsetBy(dx: 12, dy: -12).origin, size: size), on: box)
        let mark = PDFMark(id: PDFEdit.newID(), page: index, rect: rect, kind: copied.kind)
        guard change(.add(mark)) else { return false }
        controller.select(mark.id, page: index)
        return true
    }
}
