import AppKit
import PeekerKit

/// Turns Cmd+scroll and pinch over a zooming document into zoom, in Editor windows and the Peek panel. A plain scroll
/// keeps scrolling. A document whose own view pinches keeps its pinch.
@MainActor final class ZoomGestures {
    private var monitor: Any?
    /// Whether the trackpad scroll under way zooms: decided when it begins (Cmd held over the document) and kept
    /// through its momentum, so letting go of Cmd midway doesn't turn it into a scroll, and holding Cmd during a
    /// flick's momentum (to Cmd-click a link) doesn't turn it into a zoom.
    private var gestureZooms: Bool?

    init(document: any Zooming, over view: NSView) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self, weak document, weak view] event in
            guard let self, let document, let view, event.window === view.window, view.window != nil else { return event }
            let point = view.convert(event.locationInWindow, from: nil)
            let inside = view.bounds.contains(point)
            let zooms = switch event.type {
            case .scrollWheel: scrollZooms(event, inside: inside)
            case .magnify: inside && !document.pinchesNatively
            default: false
            }
            guard zooms else { return event }
            // A zooming gesture's momentum and its empty start and end are swallowed; only real movement zooms.
            if event.momentumPhase.isEmpty, let factor = Self.factor(for: event) {
                Self.zoom(document, by: factor, at: point, in: view)
            }
            return nil
        }
    }

    isolated deinit { stop() }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func scrollZooms(_ event: NSEvent, inside: Bool) -> Bool {
        let command = event.modifierFlags.contains(.command)
        // A mouse wheel's notches have no phases: each counts on its own.
        guard !event.phase.isEmpty || !event.momentumPhase.isEmpty else { return command && inside }
        if event.phase.contains(.began) || event.phase.contains(.mayBegin) { gestureZooms = command && inside }
        let zooms = gestureZooms ?? false
        if event.momentumPhase.contains(.ended) || event.momentumPhase.contains(.cancelled) || event.phase.contains(.cancelled) {
            gestureZooms = nil
        }
        return zooms
    }

    /// How much `event`, already known to zoom, zooms by. Each event's values are read only for its own type: AppKit
    /// throws on reading a scroll's magnification, which would end the monitor and let the event through unzoomed.
    static func factor(for event: NSEvent) -> Double? {
        switch event.type {
        case .scrollWheel: factor(type: .scrollWheel, command: true, deltaY: event.scrollingDeltaY, precise: event.hasPreciseScrollingDeltas,
                                  magnification: 0, pinchesNatively: false)
        case .magnify: factor(type: .magnify, command: false, deltaY: 0, precise: false, magnification: event.magnification, pinchesNatively: false)
        default: nil
        }
    }

    /// How much an event zooms, or nil when it isn't a zoom gesture. Scrolling up zooms in; a trackpad's fine deltas
    /// zoom gently and a wheel's notches in steps of about 5%. One event never zooms by more than a quarter, so a fast
    /// accelerated wheel doesn't leap.
    static func factor(type: NSEvent.EventType, command: Bool, deltaY: CGFloat, precise: Bool, magnification: CGFloat, pinchesNatively: Bool) -> Double? {
        let raw: Double? = switch type {
        case .scrollWheel where command && deltaY != 0: exp(Double(deltaY) * (precise ? 0.005 : 0.05))
        case .magnify where !pinchesNatively && magnification != 0: 1 + Double(magnification)
        default: nil
        }
        return raw.map { min(max($0, 0.8), 1.25) }
    }

    /// Zooms `document` by `factor` around `point`, given in `view`'s coordinates.
    static func zoom(_ document: any Zooming, by factor: Double, at point: NSPoint, in view: NSView) {
        guard document.zoomPercent.isFinite else { return }
        document.setZoom(document.zoomPercent * factor, around: document.contentView.convert(point, from: view))
    }
}
