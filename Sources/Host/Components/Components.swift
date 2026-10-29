import AppKit
import PDFKit

/// A host-owned view a plugin drives through its reply. Plugins never supply views of their own.
protocol Component: AnyObject {
    var view: NSView { get }
    /// Handles a command verb such as "zoom-in". Returns false for verbs it doesn't know.
    func perform(_ verb: String) -> Bool
}

final class PDFComponent: Component {
    let pdfView = PDFView()
    private let url: URL

    init(url: URL) throws {
        guard let document = PDFDocument(url: url) else { throw CocoaError(.fileReadCorruptFile) }
        self.url = url
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
    }

    var view: NSView { pdfView }

    func makeThumbnails() -> NSView {
        let thumbnails = PDFThumbnailView()
        thumbnails.pdfView = pdfView
        thumbnails.thumbnailSize = NSSize(width: 90, height: 120)
        thumbnails.backgroundColor = .clear
        return thumbnails
    }

    func perform(_ verb: String) -> Bool {
        switch verb {
        case "zoom-in": pdfView.zoomIn(nil)
        case "zoom-out": pdfView.zoomOut(nil)
        case "highlight":
            for line in pdfView.currentSelection?.selectionsByLine() ?? [] {
                for page in line.pages {
                    let annotation = PDFAnnotation(bounds: line.bounds(for: page), forType: .highlight, withProperties: nil)
                    annotation.color = .systemYellow.withAlphaComponent(0.5)
                    page.addAnnotation(annotation)
                }
            }
            pdfView.clearSelection()
        case "save":
            if pdfView.document?.write(to: url) != true { NSSound.beep() }
        default:
            return false
        }
        return true
    }
}

/// Shows pixels a plugin already decoded. The host only maps memory; it never parses image files.
final class BitmapComponent: Component {
    private let scrollView = NSScrollView()

    init(node: [String: Any]) throws {
        let image = try SharedBitmapReader.image(from: node)
        let imageView = LayerImageView(image: image)
        scrollView.documentView = imageView
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1
        scrollView.maxMagnification = 16
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = false
        imageView.autoresizingMask = [.width, .height]
    }

    var view: NSView { scrollView }

    func perform(_ verb: String) -> Bool {
        switch verb {
        case "zoom-in": scrollView.magnification *= 1.25
        case "zoom-out": scrollView.magnification /= 1.25
        case "zoom-fit": scrollView.magnification = 1
        default: return false
        }
        return true
    }

    private final class LayerImageView: NSView {
        init(image: CGImage) {
            super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
            wantsLayer = true
            layer?.contents = image
            layer?.contentsGravity = .resizeAspect
        }

        required init?(coder: NSCoder) { fatalError("not used") }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            if let clip = superview { frame = clip.bounds }
        }
    }
}

enum SharedBitmapReader {
    struct Invalid: Error {}

    /// Maps the plugin's bitmap file, after checking that the plugin's numbers can't make the host read out of bounds.
    static func image(from node: [String: Any]) throws -> CGImage {
        guard let path = node["file"] as? String, let width = node["width"] as? Int, let height = node["height"] as? Int,
              let bytesPerRow = node["bytesPerRow"] as? Int,
              (1...SharedBitmapFormat.maxDimension).contains(width), (1...SharedBitmapFormat.maxDimension).contains(height),
              bytesPerRow >= width * 4, bytesPerRow <= width * 4 + 64 else { throw Invalid() }
        let url = URL(filePath: path).standardizedFileURL
        guard url.deletingLastPathComponent().path == FileManager.default.temporaryDirectory.standardizedFileURL.path,
              url.lastPathComponent.hasPrefix(SharedBitmapFormat.prefix) else { throw Invalid() }

        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { throw Invalid() }
        defer { close(fd) }
        unlink(url.path)  // the mapping outlives the name
        let size = bytesPerRow * height
        var info = stat()
        guard fstat(fd, &info) == 0, Int(info.st_size) >= size,
              let memory = mmap(nil, size, PROT_READ, MAP_PRIVATE, fd, 0), memory != MAP_FAILED else { throw Invalid() }
        guard let provider = CGDataProvider(dataInfo: nil, data: memory, size: size, releaseData: { _, data, size in
            munmap(UnsafeMutableRawPointer(mutating: data), size)
        }) else {
            munmap(memory, size)
            throw Invalid()
        }
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: bitmapInfo, provider: provider,
                                  decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw Invalid() }
        return image
    }
}

/// Plain container whose single child view fills it.
final class HolderViewController: NSViewController {
    override func loadView() { view = NSView() }

    func show(_ child: NSView) {
        view.subviews.forEach { $0.removeFromSuperview() }
        child.frame = view.bounds
        child.autoresizingMask = [.width, .height]
        view.addSubview(child)
    }
}

/// Sidebar panels a plugin can ask for: outline, thumbnails, info.
enum Sidebar {
    static func make(_ panels: [[String: Any]], component: Component?, onAnchor: @escaping (Int) -> Void) -> NSView? {
        let views = panels.compactMap { panel -> NSView? in
            switch panel["type"] as? String {
            case "thumbnails": return (component as? PDFComponent)?.makeThumbnails()
            case "outline": return outline(panel["items"] as? [[String: Any]] ?? [], onAnchor: onAnchor)
            case "info": return info(panel["rows"] as? [[String]] ?? [])
            default: return nil
            }
        }
        guard !views.isEmpty else { return nil }
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fill
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 10, right: 10)
        stack.spacing = 14
        for view in views where view is PDFThumbnailView || view is NSScrollView {
            view.setContentHuggingPriority(.defaultLow, for: .vertical)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -20).isActive = true
        }
        return stack
    }

    private static func outline(_ items: [[String: Any]], onAnchor: @escaping (Int) -> Void) -> NSView? {
        guard !items.isEmpty else { return nil }
        return OutlineList(items: items, onAnchor: onAnchor).scrollView
    }

    private static func info(_ rows: [[String]]) -> NSView? {
        let cells = rows.filter { $0.count == 2 }.map { row -> [NSView] in
            let label = NSTextField(labelWithString: row[0])
            label.textColor = .secondaryLabelColor
            label.font = .systemFont(ofSize: 11)
            let value = NSTextField(wrappingLabelWithString: row[1])
            value.font = .systemFont(ofSize: 11)
            value.isSelectable = true
            return [label, value]
        }
        guard !cells.isEmpty else { return nil }
        let grid = NSGridView(views: cells)
        grid.columnSpacing = 8
        grid.rowSpacing = 4
        grid.column(at: 0).xPlacement = .trailing
        return grid
    }

    /// A table, not a stack of buttons: it only creates the visible rows, so 4,000 headings stay instant.
    private final class OutlineList: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        let scrollView = NSScrollView()
        private let table = NSTableView()
        private let items: [(title: String, level: Int, anchor: Int)]
        private let onAnchor: (Int) -> Void

        init(items: [[String: Any]], onAnchor: @escaping (Int) -> Void) {
            self.items = items.map { ($0["title"] as? String ?? "", $0["level"] as? Int ?? 1, $0["anchor"] as? Int ?? 0) }
            self.onAnchor = onAnchor
            super.init()
            table.addTableColumn(NSTableColumn(identifier: .init("title")))
            table.headerView = nil
            table.style = .sourceList
            table.rowHeight = 20
            table.dataSource = self
            table.delegate = self
            table.target = self
            table.action = #selector(clicked)
            scrollView.documentView = table
            scrollView.hasVerticalScroller = true
            scrollView.drawsBackground = false
            objc_setAssociatedObject(scrollView, Unmanaged.passUnretained(self).toOpaque(), self, .OBJC_ASSOCIATION_RETAIN)
        }

        func numberOfRows(in tableView: NSTableView) -> Int { items.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let item = items[row]
            let cell = tableView.makeView(withIdentifier: .init("cell"), owner: nil) as? NSTextField ?? {
                let field = NSTextField(labelWithString: "")
                field.identifier = .init("cell")
                field.lineBreakMode = .byTruncatingTail
                return field
            }()
            cell.stringValue = String(repeating: "   ", count: max(0, item.level - 1)) + item.title
            cell.font = .systemFont(ofSize: 12, weight: item.level == 1 ? .semibold : .regular)
            return cell
        }

        @objc private func clicked() {
            guard items.indices.contains(table.clickedRow) else { return }
            onAnchor(items[table.clickedRow].anchor)
        }
    }

    private final class FlippedContainer: NSView {
        init(_ content: NSView) {
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false
            content.translatesAutoresizingMaskIntoConstraints = false
            addSubview(content)
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: leadingAnchor),
                content.trailingAnchor.constraint(equalTo: trailingAnchor),
                content.topAnchor.constraint(equalTo: topAnchor),
                content.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        required init?(coder: NSCoder) { fatalError("not used") }
        override var isFlipped: Bool { true }
    }
}
