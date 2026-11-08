import AppKit
import CoreGraphics
import CoreText
import Foundation
import PeekerKit

/// Draws markup marks over an image with Core Graphics, the same way on screen and in the saved file. Safe off the
/// main thread.
nonisolated enum MarkRenderer {
    /// `image` with `marks` drawn on it. Marks are in pixels of an image of `imageSize` (the full image as edited);
    /// `image` may be a smaller decode of it, and the marks scale to it. Nil when there are no marks or no context.
    static func render(_ marks: [ImageMark], on image: CGImage, imageSize: CGSize) -> CGImage? {
        guard !marks.isEmpty, imageSize.width > 0, let context = ImageEditing.context(like: image, width: image.width, height: image.height)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        draw(marks, on: image, imageSize: imageSize, in: context)
        return context.makeImage()
    }

    /// Draws `marks` into `context`, which holds `image` at its pixel size.
    static func draw(_ marks: [ImageMark], on image: CGImage, imageSize: CGSize, in context: CGContext) {
        let scale = CGFloat(image.width) / imageSize.width
        context.saveGState()
        // From here on, image pixels from the top left.
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: scale, y: -scale)
        for mark in marks {
            if case .pixelate(let rect, let strength) = mark.kind { pixelate(rect, strength: strength, of: image, scale: scale, imageSize: imageSize, in: context) }
        }
        drawStrokes(marks, imageSize: imageSize, in: context)
        context.restoreGState()
    }

    /// Draws every mark but Pixelate over `image`, shown at `rect` in an unflipped view, at the view's resolution, so
    /// lines and text stay sharp at any zoom. Pixelate needs the image's pixels, so it's in the shown image instead.
    /// Steps are numbered among `numbering`, every mark, so a step being dragged keeps its number.
    static func drawOnScreen(_ marks: [ImageMark], numbering: [ImageMark], over image: CGImage, imageSize: CGSize, in rect: CGRect, context: CGContext) {
        guard imageSize.width > 0, imageSize.height > 0, !marks.isEmpty else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: rect.width / imageSize.width, y: -rect.height / imageSize.height)
        drawStrokes(marks, numbers: ImageMark.stepNumbers(numbering), imageSize: imageSize, underlay: image, in: context)
        context.restoreGState()
    }

    /// Markers, Spotlight's dimming, then the other marks, in image pixels from the top left. A marker multiplies with
    /// what's under it; with `underlay`, that's drawn under the marker's stroke first, since an empty view has nothing
    /// to multiply with.
    private static func drawStrokes(_ marks: [ImageMark], numbers: [String: Int]? = nil, imageSize: CGSize, underlay: CGImage? = nil, in context: CGContext) {
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for mark in marks where mark.kind.isMarker {
            if let underlay { drawUnderlay(underlay, under: mark, imageSize: imageSize, in: context) }
            draw(mark, number: nil, in: context)
        }
        let lit = marks.compactMap { mark -> (CGRect, Bool)? in if case .spotlight(let rect, let ellipse) = mark.kind { (rect.standardized, ellipse) } else { nil } }
        if !lit.isEmpty { dim(outside: lit, imageSize: imageSize, in: context) }
        let numbers = numbers ?? ImageMark.stepNumbers(marks)
        for mark in marks where !mark.kind.isMarker { draw(mark, number: numbers[mark.id], in: context) }
    }

    private static func drawUnderlay(_ image: CGImage, under mark: ImageMark, imageSize: CGSize, in context: CGContext) {
        guard case .marker(let points) = mark.kind, let first = points.first else { return }
        context.saveGState()
        context.setLineWidth(mark.width * 4)
        context.setLineCap(.butt)
        context.move(to: first)
        for point in points.dropFirst() { context.addLine(to: point) }
        context.replacePathWithStrokedPath()
        if !context.isPathEmpty {
            context.clip()
            context.translateBy(x: 0, y: imageSize.height)
            context.scaleBy(x: 1, y: -1)
            context.draw(image, in: CGRect(origin: .zero, size: imageSize))
        }
        context.restoreGState()
    }

    /// Draws `mark` over the image shown at `rect` in an unflipped view, as the mark being drawn or dragged: a pixelate
    /// area as a dashed outline, since its pixels come only once it's placed, and a spotlight not at all.
    static func drawDraft(_ mark: ImageMark, number: Int?, imageSize: CGSize, in rect: CGRect, context: CGContext) {
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: rect.width / imageSize.width, y: -rect.height / imageSize.height)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        switch mark.kind {
        case .pixelate(let area, _):
            context.setStrokeColor(CGColor(gray: 0.5, alpha: 1))
            context.setLineWidth(max(mark.width / 2, 1))
            context.setLineDash(phase: 0, lengths: [mark.width * 2, mark.width * 2])
            context.stroke(area.standardized)
        case .spotlight:
            break  // the marks view dims around it with the other spotlights
        default:
            draw(mark, number: number, in: context)
        }
        context.restoreGState()
    }

    private static func draw(_ mark: ImageMark, number: Int?, in context: CGContext) {
        let color = mark.color.cgColor, width = mark.width
        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(width)
        switch mark.kind {
        case .arrow(let from, let to):
            let angle = atan2(to.y - from.y, to.x - from.x), head = width * 4
            let base = CGPoint(x: to.x - cos(angle) * head * 0.8, y: to.y - sin(angle) * head * 0.8)
            context.strokeLineSegments(between: [from, base])
            context.move(to: to)
            context.addLine(to: CGPoint(x: to.x - cos(angle - 0.45) * head, y: to.y - sin(angle - 0.45) * head))
            context.addLine(to: CGPoint(x: to.x - cos(angle + 0.45) * head, y: to.y - sin(angle + 0.45) * head))
            context.closePath()
            context.fillPath()
        case .box(let rect, let ellipse):
            ellipse ? context.strokeEllipse(in: rect.standardized) : context.stroke(rect.standardized)
        case .pen(let points):
            stroke(points, in: context)
        case .marker(let points):
            context.saveGState()
            context.setBlendMode(.multiply)
            context.setStrokeColor(mark.color.cgColor.copy(alpha: 0.4) ?? color)
            context.setLineWidth(width * 4)
            context.setLineCap(.butt)
            stroke(points, in: context)
            context.restoreGState()
        case .step(let center):
            let radius = width * ImageMark.stepScale
            context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            let line = textLine("\(number ?? 1)", size: radius * 1.2, bold: true, color: contrast(to: mark.color))
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            drawLine(line, at: CGPoint(x: center.x - bounds.width / 2 - bounds.minX, y: center.y + bounds.height / 2 + bounds.minY), in: context)
        case .text(let origin, let string, let style):
            drawText(string, at: origin, size: width * ImageMark.textScale, color: mark.color, style: style, in: context)
        case .pixelate, .spotlight:
            break  // drawn first, under everything
        }
    }

    private static func stroke(_ points: [CGPoint], in context: CGContext) {
        guard let first = points.first else { return }
        context.move(to: first)
        if points.count == 1 { context.addLine(to: first) }  // a dot
        for point in points.dropFirst() { context.addLine(to: point) }
        context.strokePath()
    }

    /// Averages `rect` into blocks sized by `strength`.
    private static func pixelate(_ rect: CGRect, strength: Double, of image: CGImage, scale: CGFloat, imageSize: CGSize, in context: CGContext) {
        let area = rect.standardized.intersection(CGRect(origin: .zero, size: imageSize))
        guard !area.isEmpty else { return }
        let block = MarkStyle.block(strength: strength, imageSize: imageSize)
        let pixels = CGRect(x: area.minX * scale, y: area.minY * scale, width: area.width * scale, height: area.height * scale).integral
        guard let part = image.cropping(to: pixels) else { return }
        let columns = max(Int((area.width / block).rounded(.up)), 1), rows = max(Int((area.height / block).rounded(.up)), 1)
        guard let small = ImageEditing.context(like: part, width: columns, height: rows) else { return }
        small.interpolationQuality = .medium
        small.draw(part, in: CGRect(x: 0, y: 0, width: columns, height: rows))
        guard let blocks = small.makeImage() else { return }
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: area.minX, y: area.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(blocks, in: CGRect(x: 0, y: 0, width: area.width, height: area.height))
        context.restoreGState()
    }

    private static func dim(outside lit: [(rect: CGRect, ellipse: Bool)], imageSize: CGSize, in context: CGContext) {
        context.saveGState()
        context.addRect(CGRect(origin: .zero, size: imageSize))
        for (rect, ellipse) in lit { ellipse ? context.addEllipse(in: rect) : context.addRect(rect) }
        context.setFillColor(CGColor(gray: 0, alpha: 0.5))
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }

    /// Text from its top left in its style: plain, with a thin outline or a drop shadow, or white or black on a box
    /// of its color.
    private static func drawText(_ string: String, at origin: CGPoint, size: CGFloat, color: RGBA, style: TextStyle, in context: CGContext) {
        let lines = string.components(separatedBy: "\n")
        let font = font(style, size: size) as CTFont
        let label = style.effect == .label
        let lineHeight = size * 1.25, pad = size * 0.35
        if label {
            let widest = lines.map { CTLineGetTypographicBounds(textLine($0, font: font, color: color.cgColor), nil, nil, nil) }.max() ?? 0
            let box = CGRect(x: origin.x, y: origin.y, width: widest + pad * 2, height: lineHeight * CGFloat(lines.count) + pad)
            context.setFillColor(color.cgColor)
            context.addPath(CGPath(roundedRect: box, cornerWidth: pad, cornerHeight: pad, transform: nil))
            context.fillPath()
        }
        let ink = label ? contrast(to: color) : color.cgColor
        // A design with no italic, such as Rounded, leans instead.
        let slanted = style.italic && !CTFontGetSymbolicTraits(font).contains(.traitItalic)
        context.saveGState()
        if style.effect == .shadow {
            // Shadow offsets ignore the transform, so they're scaled by it to look the same at any zoom and when saved.
            let scale = hypot(context.ctm.a, context.ctm.b)
            context.setShadow(offset: CGSize(width: size * 0.05 * scale, height: -size * 0.07 * scale), blur: size * 0.15 * scale,
                              color: CGColor(gray: 0, alpha: 0.6))
        }
        for (index, text) in lines.enumerated() {
            let baseline = CGPoint(x: origin.x + (label ? pad : 0), y: origin.y + (label ? pad / 2 : 0) + size + lineHeight * CGFloat(index))
            if style.effect == .outline {
                drawLine(textLine(text, font: font, color: contrast(to: color), stroke: size * 0.12), at: baseline, slanted: slanted, in: context)
            }
            drawLine(textLine(text, font: font, color: ink), at: baseline, slanted: slanted, in: context)
        }
        context.restoreGState()
    }

    /// The font for markup text of `style` at `size`; a design with no italic, such as Rounded, comes back upright.
    static func font(_ style: TextStyle, size: CGFloat) -> NSFont {
        let design: NSFontDescriptor.SystemDesign? = switch style.font {
        case .system: nil
        case .serif: .serif
        case .rounded: .rounded
        case .mono: .monospaced
        }
        var descriptor = NSFont.systemFont(ofSize: size, weight: style.bold ? .bold : .regular).fontDescriptor
        if let design, let designed = descriptor.withDesign(design) { descriptor = designed }
        if style.italic { descriptor = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.italic)) }
        return NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size)
    }

    private static func textLine(_ text: String, size: CGFloat, bold: Bool, color: CGColor) -> CTLine {
        let font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        return textLine(text, font: font, color: color)
    }

    private static func textLine(_ text: String, font: CTFont, color: CGColor, stroke: CGFloat = 0) -> CTLine {
        var attributes: [NSAttributedString.Key: Any] = [.init(kCTFontAttributeName as String): font, .init(kCTForegroundColorAttributeName as String): color]
        if stroke > 0 {
            attributes[.init(kCTStrokeColorAttributeName as String)] = color
            attributes[.init(kCTStrokeWidthAttributeName as String)] = stroke / CTFontGetSize(font) * 100  // percent of the font size, stroked only
        }
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }

    /// Draws a line with its baseline at `point`, upright in the flipped context, or leaning right when `slanted`.
    private static func drawLine(_ line: CTLine, at point: CGPoint, slanted: Bool = false, in context: CGContext) {
        context.saveGState()
        context.textMatrix = CGAffineTransform(a: 1, b: 0, c: slanted ? 0.2 : 0, d: -1, tx: 0, ty: 0)
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
    }

    /// White on dark colors, black on light ones.
    static func contrast(to color: RGBA) -> CGColor {
        let luminance = 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue
        return luminance > 0.6 ? CGColor(gray: 0, alpha: 1) : CGColor(gray: 1, alpha: 1)
    }
}
