import AppKit
import ImageIO

/// Plays an animated image's frames into the canvas with the file's own timing and loop count. A click on the canvas
/// pauses on the frame shown, and the next plays on from there.
final class AnimationPlayer {
    private let url: URL
    private weak var canvas: ImageCanvas?
    private(set) var isPaused = false
    /// The frame shown, so a paused animation resumes from it.
    private(set) var frameIndex = 0
    /// Tells the running animation from one replaced by a pause and resume.
    private var run = 0

    init(url: URL, canvas: ImageCanvas) {
        self.url = url
        self.canvas = canvas
        canvas.onClick = { [weak self] in self?.toggle() }
        play(from: 0)
    }

    func toggle() {
        isPaused.toggle()
        if !isPaused { play(from: frameIndex) }
    }

    private func play(from start: Int) {
        run += 1
        let current = run
        let status = CGAnimateImageAtURLWithBlock(url as CFURL, [kCGImageAnimationStartIndex: start] as CFDictionary) { [weak self] index, image, stop in
            MainActor.assumeIsolated {
                guard let self, self.run == current, !self.isPaused, let canvas = self.canvas else {
                    stop.pointee = true
                    return
                }
                self.frameIndex = index
                canvas.image = image
            }
        }
        if status != noErr { isPaused = true }
    }
}
