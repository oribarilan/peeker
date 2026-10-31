import AppKit

/// A drawn signature: strokes within 0...1 of their own bounds (origin bottom left), and its height over its width.
nonisolated struct Signature: Equatable, Sendable {
    let strokes: [[CGPoint]]
    let aspect: Double

    /// Normalizes strokes drawn in any coordinates; nil when nothing was drawn.
    init?(strokes raw: [[CGPoint]]) {
        let strokes = raw.filter { !$0.isEmpty }
        let points = strokes.joined()
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
        let width = max(maxX - minX, 1), height = max(maxY - minY, 1)
        self.strokes = strokes.map { $0.map { CGPoint(x: ($0.x - minX) / width, y: ($0.y - minY) / height) } }
        aspect = min(max(height / width, 0.05), 1.5)
    }
}

/// The last signature drawn, kept only while Peeker runs. Peeker never writes a signature anywhere but into the
/// PDF it's placed in.
enum SignatureMemory {
    static var last: Signature?
}

/// The sheet where the user draws a signature, with Clear, Cancel, Done and Use Last Signature.
final class SignaturePad: NSWindowController {
    private let canvas = SignatureCanvas()
    private let done = NSButton(title: "Done", target: nil, action: nil)
    private var completion: ((Signature?) -> Void)?

    static func finish(with signature: Signature) {
        SignatureMemory.last = signature
    }

    /// Shows the pad on `window`; `placing` gets the signature after Done or Use Last Signature.
    static func present(on window: NSWindow, placing: @escaping (Signature) -> Void) {
        let pad = SignaturePad()
        pad.completion = { signature in
            if let signature { placing(signature) }
        }
        guard let sheet = pad.window else { return }
        window.beginSheet(sheet) { _ in withExtendedLifetime(pad) {} }
    }

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 250), styleMask: [.titled], backing: .buffered, defer: false)
        super.init(window: window)
        let prompt = NSTextField(labelWithString: "Sign with your trackpad or mouse.")
        prompt.textColor = .secondaryLabelColor
        canvas.onChange = { [weak self] in self?.done.isEnabled = !(self?.canvas.strokes.isEmpty ?? true) }
        let useLast = NSButton(title: "Use Last Signature", target: self, action: #selector(useLast(_:)))
        useLast.isHidden = SignatureMemory.last == nil
        let clear = NSButton(title: "Clear", target: self, action: #selector(clear(_:)))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        done.target = self
        done.action = #selector(finish(_:))
        done.keyEquivalent = "\r"
        done.isEnabled = false
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let buttons = NSStackView(views: [useLast, spacer, clear, cancel, done])
        let stack = NSStackView(views: [prompt, canvas, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = stack
        NSLayoutConstraint.activate([
            canvas.widthAnchor.constraint(equalToConstant: 440),
            canvas.heightAnchor.constraint(equalToConstant: 150),
            buttons.widthAnchor.constraint(equalTo: canvas.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func close(with signature: Signature?) {
        if let signature { Self.finish(with: signature) }
        completion?(signature)
        completion = nil
        if let window { window.sheetParent?.endSheet(window) }
    }

    @objc private func useLast(_ sender: Any?) { close(with: SignatureMemory.last) }
    @objc private func clear(_ sender: Any?) { canvas.clear() }
    @objc private func cancel(_ sender: Any?) { close(with: nil) }
    @objc private func finish(_ sender: Any?) { close(with: Signature(strokes: canvas.strokes)) }
}

/// Records mouse and trackpad strokes over a signature line.
final class SignatureCanvas: NSView {
    private(set) var strokes: [[CGPoint]] = []
    var onChange: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    func clear() {
        strokes = []
        needsDisplay = true
        onChange?()
    }

    override func mouseDown(with event: NSEvent) {
        strokes.append([convert(event.locationInWindow, from: nil)])
        needsDisplay = true
        onChange?()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // Sampling smooths the line and keeps the stroke small.
        guard let last = strokes.last?.last, hypot(point.x - last.x, point.y - last.y) >= 1.5 else { return }
        strokes[strokes.count - 1].append(point)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        NSColor.separatorColor.setStroke()
        let line = NSBezierPath()
        line.move(to: CGPoint(x: 20, y: 36))
        line.line(to: CGPoint(x: bounds.maxX - 20, y: 36))
        line.stroke()
        NSColor.black.setStroke()
        for stroke in strokes {
            guard let first = stroke.first else { continue }
            let path = NSBezierPath()
            path.lineWidth = 2
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.move(to: first)
            stroke.dropFirst().forEach(path.line(to:))
            if stroke.count == 1 { path.line(to: CGPoint(x: first.x + 0.5, y: first.y)) }
            path.stroke()
        }
    }
}
