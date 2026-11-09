import Foundation

/// Paces the many steps of a zoom gesture for a view whose redraw is costly: the first step draws at once, later ones
/// at most every `interval`, and the last one always. Meanwhile the document reports the size it's heading to, so each
/// step builds on the one before and the zoom control follows at once.
@MainActor public final class ZoomPacer {
    private let interval: Duration
    private var lastDraw: ContinuousClock.Instant?
    private var pending: Task<Void, Never>?

    public init(interval: Duration = .milliseconds(100)) {
        self.interval = interval
    }

    /// Runs `draw` now, or once `interval` has passed since the last draw, replacing a draw still waiting.
    public func draw(_ draw: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = nil
        let now = ContinuousClock.now
        guard let lastDraw, now - lastDraw < interval else {
            self.lastDraw = now
            draw()
            return
        }
        pending = Task { [weak self] in
            try? await Task.sleep(until: lastDraw + (self?.interval ?? .zero))
            guard !Task.isCancelled, let self else { return }
            self.lastDraw = .now
            pending = nil
            draw()
        }
    }

    /// Drops a draw still waiting, for a menu step that draws at once.
    public func cancel() {
        pending?.cancel()
        pending = nil
    }
}
