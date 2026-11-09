import AppKit

/// A document that zooms. The host shows its zoom in a control in Editor windows, and turns Cmd+scroll and pinch into
/// `setZoom` calls, in windows and the Peek panel. The View menu's zoom tools (`zoom-in`, `zoom-out`, `zoom-fit`,
/// `zoom-actual`) stay the document's own; the control's buttons run them, so their steps match the menu's.
@MainActor public protocol Zooming: PluginDocument {
    /// The zoom as a percentage of actual size: 100 is a PDF at 100%, an image at one image pixel per screen pixel,
    /// or text at the format's default size.
    var zoomPercent: Double { get }
    /// How far it zooms, in the same percentages.
    var zoomRange: ClosedRange<Double> { get }
    /// Zooms to `percent`, clamped to `zoomRange`, keeping `point` (in `contentView`'s coordinates) where it is when
    /// the format can, or the middle when `point` is nil.
    func setZoom(_ percent: Double, around point: NSPoint?)
    /// Set by the host: call it whenever `zoomPercent` changes, by any means.
    var onZoomChange: (() -> Void)? { get set }
    /// True when the document's own view already zooms on pinch, so the host leaves pinch to it. False by default.
    var pinchesNatively: Bool { get }
}

public extension Zooming {
    var pinchesNatively: Bool { false }
}
