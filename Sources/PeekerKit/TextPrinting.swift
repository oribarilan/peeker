import AppKit

/// Printing for documents that show text: dark on white whatever the system appearance, wrapped to the paper's
/// width, with the system header (job title, date) and footer (page number).
@MainActor public enum TextPrinting {
    /// A print job for `text`. Dynamic colors in it, such as `labelColor`, print in their light variant.
    public static func job(for text: NSAttributedString, info: NSPrintInfo) -> NSPrintOperation {
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = false
        info.isVerticallyCentered = false
        info.dictionary()[NSPrintInfo.AttributeKey.headerAndFooter] = true
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        view.appearance = NSAppearance(named: .aqua)
        view.backgroundColor = .white
        view.textStorage?.setAttributedString(text)
        view.isVerticallyResizable = true
        if let container = view.textContainer { view.layoutManager?.ensureLayout(for: container) }
        view.sizeToFit()
        return NSPrintOperation(view: view, printInfo: info)
    }
}
