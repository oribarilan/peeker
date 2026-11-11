import AppKit
import PeekerKit
@testable import PeekerImage
import Testing

/// An image of `width` × `height` pixels in an off-screen window of `size` points, fitted to it.
private func shown(width: Int = 400, height: Int = 200, in size: NSSize = NSSize(width: 400, height: 200)) async throws -> (ImageDocument, NSWindow) {
    let url = try imageFile(try cornerImage(width: width, height: height), type: .png)
    let document = try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, maxPixels: 1000)
    return (document, offscreenWindow(holding: document.contentView, width: size.width, height: size.height))
}

@Suite(.serialized) struct ImageZoomContract {
    @Test func actualSizeIs100Percent() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let actual = ImageDocument.actualMagnification(
            pixelWidth: 400, backingScale: window.backingScaleFactor, fittedWidth: document.canvas.imageRect.width)
        #expect(abs(document.zoomPercent - 100 / actual) < 0.01, "fitted")
        #expect(document.perform("zoom-actual"))
        #expect(abs(document.zoomPercent - 100) < 0.01)
        #expect(document.pinchesNatively)
    }

    /// A small image's actual size is below an eighth of fit, where zooming out otherwise stops.
    @Test func aSmallImageStillReachesActualSize() async throws {
        let (document, window) = try await shown(width: 64, height: 64, in: NSSize(width: 640, height: 640))
        defer { window.close() }
        #expect(document.zoomRange.contains(100))
        document.setZoom(100, around: nil)
        #expect(abs(document.zoomPercent - 100) < 0.01)
    }

    @Test func setZoomStaysInItsRange() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        document.setZoom(1_000_000, around: nil)
        #expect(abs(document.zoomPercent - document.zoomRange.upperBound) < 0.01)
        document.setZoom(0, around: nil)
        #expect(abs(document.zoomPercent - document.zoomRange.lowerBound) < 0.01)
    }

    @Test func setZoomMagnifiesAndSaysSo() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        var changes = 0
        document.onZoomChange = { changes += 1 }
        document.setZoom(300, around: nil)
        #expect(abs(document.zoomPercent - 300) < 0.01)
        #expect(changes > 0)
    }

    @Test(arguments: ["zoom-in", "zoom-out", "zoom-actual", "zoom-fit"])
    func theMenuToolsSaySo(_ tool: String) async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        document.setZoom(150, around: nil)
        var changes = 0
        document.onZoomChange = { changes += 1 }
        #expect(document.perform(tool))
        #expect(changes > 0)
    }

    @Test func aResizeThatChangesTheFitSaysSo() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        let before = document.zoomPercent
        var changes = 0
        document.onZoomChange = { changes += 1 }
        document.contentView.setFrameSize(NSSize(width: 200, height: 100))
        #expect(changes > 0)
        #expect(abs(document.zoomPercent - before / 2) < 0.01)
    }

    @Test func aCropSaysSo() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        var changes = 0
        document.onZoomChange = { changes += 1 }
        document.apply(.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1)))
        #expect(changes > 0)
    }

    @Test func theSpotUnderThePointerStaysPut() async throws {
        let (document, window) = try await shown()
        defer { window.close() }
        // Scrollers that take room, as without a trackpad, would move the image as they appear.
        document.contentScrollView.scrollerStyle = .overlay
        let canvas = document.canvas, pointer = NSPoint(x: 100, y: 60)  // in the content view
        let onImage = canvas.convert(pointer, from: document.contentView)
        document.setZoom(document.zoomPercent * 3, around: pointer)
        #expect(abs(document.contentScrollView.magnification - 3) < 0.001)
        let after = document.contentView.convert(onImage, from: canvas)
        #expect(abs(after.x - pointer.x) < 1 && abs(after.y - pointer.y) < 1, "\(after) should be \(pointer)")
    }

    @Test func zoomingInStartsTheFullDecode() async throws {
        let (document, window) = try await shown(width: 2000, height: 1000, in: NSSize(width: 500, height: 250))
        defer { window.close() }
        document.setZoom(document.zoomPercent * 2, around: nil)
        await (try #require(document.sharpening)).value
        #expect(document.shownSize == CGSize(width: 2000, height: 1000))
    }
}
