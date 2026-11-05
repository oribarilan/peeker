import AppKit
import PDFKit
import PeekerKit
import UniformTypeIdentifiers

/// The PDF tools that bring in or write other files: Insert Pages from File…, Save Selected Pages As… and Split….
extension PDFPluginDocument {
    /// The pages of `urls` as one PDF: each PDF's pages, and each image as a page of its size. Throws, naming the
    /// file, for anything else or a locked PDF.
    static func insertable(from urls: [URL]) throws(PluginError) -> (data: Data, count: Int) {
        let combined = PDFDocument()
        for url in urls {
            let name = url.lastPathComponent
            if let pdf = PDFDocument(url: url) {
                guard !pdf.isLocked else { throw PluginError("“\(name)” is password protected.") }
                for index in 0..<pdf.pageCount { if let page = pdf.page(at: index)?.copy() as? PDFPage { combined.insert(page, at: combined.pageCount) } }
            } else if let image = NSImage(contentsOf: url), image.isValid, let page = PDFPage(image: image) {
                combined.insert(page, at: combined.pageCount)
            } else {
                throw PluginError("“\(name)” isn't a PDF or an image.")
            }
        }
        guard combined.pageCount > 0, let data = combined.dataRepresentation() else { throw PluginError("There were no pages to insert.") }
        return (data, combined.pageCount)
    }

    /// Inserts the pages of `urls` after the last selected page, or the one shown; one Undo step.
    @discardableResult
    func insertPages(from urls: [URL]) -> Bool {
        let inserted: (data: Data, count: Int)
        do throws(PluginError) {
            inserted = try Self.insertable(from: urls)
        } catch {
            showProblem(error.message)
            return false
        }
        let at = targetPages.last.map { $0 + 1 } ?? document.pageCount
        return change(.restorePages(pages: Array(at..<(at + inserted.count)), token: PDFEdit.newID(), data: inserted.data))
    }

    /// Writes copies of the pages at `indices`, as shown, to `destination`.
    func writePages(_ indices: [Int], to destination: URL) throws(PluginError) {
        let copy = PDFDocument()
        for index in indices.sorted() { if let page = document.page(at: index)?.copy() as? PDFPage { copy.insert(page, at: copy.pageCount) } }
        guard copy.pageCount > 0, let data = copy.dataRepresentation() else { throw PluginError("“\(destination.lastPathComponent)” couldn't be written.") }
        try FileReplacement.replaceContents(ofFileAt: destination.path, with: data)
    }

    /// Where each part starts: every page, or page 1 and each selected page after it.
    static func splitStarts(every: Bool, selected: [Int], pageCount: Int) -> [Int] {
        every ? Array(0..<pageCount) : Array(Set([0] + selected.filter { (1..<pageCount).contains($0) })).sorted()
    }

    /// Writes one file per run of pages starting at each of `starts`, next to the file, as “name 1.pdf” and on,
    /// skipping names that exist. Returns the files written.
    @discardableResult
    func split(at starts: [Int]) throws(PluginError) -> [URL] {
        let folder = url.deletingLastPathComponent(), name = url.deletingPathExtension().lastPathComponent
        var number = 1, written: [URL] = []
        let ends = Array(starts.dropFirst()) + [document.pageCount]
        for (start, end) in zip(starts, ends) where start < end {
            var target = folder.appending(path: "\(name) \(number).pdf")
            while FileManager.default.fileExists(atPath: target.path) {
                number += 1
                target = folder.appending(path: "\(name) \(number).pdf")
            }
            try writePages(Array(start..<end), to: target)
            written.append(target)
            number += 1
        }
        return written
    }

    // MARK: Sheets

    /// Says what went wrong in a sheet on the window.
    func showProblem(_ message: String) {
        guard let window = pdfView.window else { return NSSound.beep() }
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: window)
    }

    func chooseFilesToInsert() {
        guard let window = pdfView.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf, .image]
        panel.allowsMultipleSelection = true
        panel.prompt = "Insert"
        panel.message = "The pages go after the selected page."
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK else { return }
            self?.insertPages(from: panel.urls)
        }
    }

    func chooseWhereToSavePages() {
        guard let window = pdfView.window else { return }
        let pages = targetPages
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(url.deletingPathExtension().lastPathComponent) pages.pdf"
        panel.directoryURL = url.deletingLastPathComponent()
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let destination = panel.url, let self else { return }
            do throws(PluginError) { try writePages(pages, to: destination) } catch { showProblem(error.message) }
        }
    }

    func askHowToSplit() {
        guard let window = pdfView.window else { return }
        let selected = targetPages.filter { $0 > 0 }
        let alert = NSAlert()
        alert.messageText = "Split “\(url.lastPathComponent)”"
        alert.informativeText = "The files go next to it, named “\(url.deletingPathExtension().lastPathComponent) 1.pdf” and on."
        alert.addButton(withTitle: "Every Page")
        let atSelected = alert.addButton(withTitle: "At Selected Pages")
        atSelected.isEnabled = !selected.isEmpty
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self, response != .alertThirdButtonReturn else { return }
            let starts = Self.splitStarts(every: response == .alertFirstButtonReturn, selected: selected, pageCount: document.pageCount)
            do throws(PluginError) { try split(at: starts) } catch { showProblem(error.message) }
        }
    }
}
