import AppKit
import PeekerKit
import Testing

private enum ZoomingPlugin: Plugin {
    static let id = "zooming"
    static let name = "Zooming"
    static let defaultExtensions: [String] = []
    static let tools = ["zoom-in", "zoom-out", "zoom-fit", "zoom-actual"].map { ToolSpec(id: $0, title: $0, showsInToolbar: false) }
    static var pinches = false

    static func open(_ url: URL, context: OpenContext) async throws(PluginError) -> any PluginDocument { ZoomingDocument() }
}

/// A document that zooms in steps of 25% and records what ran.
private final class ZoomingDocument: Zooming {
    let contentView = NSView()
    var zoomPercent = 100.0
    let zoomRange: ClosedRange<Double> = 25...300
    var onZoomChange: (() -> Void)?
    var onReplace: ((any PluginDocument) -> Void)?
    var performed: [String] = []
    var lastPoint: NSPoint?
    var tools: [ToolSpec] { ZoomingPlugin.tools }
    var pinchesNatively: Bool { ZoomingPlugin.pinches }

    func perform(_ id: String) -> Bool {
        performed.append(id)
        switch id {
        case "zoom-in": setZoom(zoomPercent + 25, around: nil)
        case "zoom-out": setZoom(zoomPercent - 25, around: nil)
        case "zoom-actual": setZoom(100, around: nil)
        case "zoom-fit": setZoom(80, around: nil)
        default: return false
        }
        return true
    }

    func setZoom(_ percent: Double, around point: NSPoint?) {
        zoomPercent = min(max(percent, zoomRange.lowerBound), zoomRange.upperBound)
        lastPoint = point
        onZoomChange?()
    }
}

@MainActor private func shown(editing: Bool = true) async throws -> (DocumentViewController, ZoomingDocument) {
    let document = await loadedDocument(try TempFile.make(Data("x".utf8), name: "f.bin"), with: ZoomingPlugin.self, allowsEditing: editing)
    return (document, try #require(document.pluginDocument as? ZoomingDocument))
}

@Suite(.serialized) struct ZoomControlling {
    @Test func anEditorShowsTheZoomAndFollowsIt() async throws {
        let (document, zooming) = try await shown()
        defer { document.close() }
        let control = try #require(document.zoomControl)
        #expect(control.levelTitle == "100%")
        _ = zooming.perform("zoom-in")
        #expect(control.levelTitle == "125%")
        #expect(control.accessibilityLabel() == "Zoom")
    }

    @Test func itsButtonsRunTheZoomTools() async throws {
        let (document, zooming) = try await shown()
        defer { document.close() }
        let control = try #require(document.zoomControl)
        control.zoomInButton.performClick(nil)
        control.zoomOutButton.performClick(nil)
        #expect(zooming.performed == ["zoom-in", "zoom-out"])
    }

    @Test func thePercentageOffersActualSizeFitAndStepsWithinRange() async throws {
        let (document, zooming) = try await shown()
        defer { document.close() }
        let menu = try #require(document.zoomControl).levelMenu()
        #expect(menu.items.filter { !$0.isSeparatorItem }.map(\.title) == ["Actual Size", "Zoom to Fit", "50%", "200%"], "400% is past the range")
        let twice = try #require(menu.items.first { $0.title == "200%" })
        _ = twice.target?.perform(twice.action, with: twice)
        #expect(zooming.zoomPercent == 200)
        let fit = try #require(menu.items.first { $0.title == "Zoom to Fit" })
        _ = fit.target?.perform(fit.action, with: fit)
        #expect(zooming.performed == ["zoom-fit"])
    }

    @Test func theControlIsHiddenUntilThePointerIsOverTheDocument() async throws {
        let (document, _) = try await shown()
        defer { document.close() }
        #expect(try #require(document.zoomControl).isHidden, "takes no clicks or scrolls in its corner meanwhile")
    }

    @Test func aReplacementGetsOneFreshControl() async throws {
        let (document, zooming) = try await shown()
        defer { document.close() }
        let first = try #require(document.zoomControl)
        zooming.onReplace?(ZoomingDocument())
        #expect(document.zoomControl !== first && first.superview == nil)
    }

    @Test func thePeekPanelHasNoControl() async throws {
        let (document, _) = try await shown(editing: false)
        defer { document.close() }
        #expect(document.zoomControl == nil)
    }

    @Test func cmdScrollAndPinchBecomeZoomSteps() {
        #expect(
            ZoomGestures.factor(type: .scrollWheel, command: true, deltaY: 10, precise: true, magnification: 0, pinchesNatively: false).map { $0 > 1 }
                == true)
        #expect(
            ZoomGestures.factor(type: .scrollWheel, command: true, deltaY: -10, precise: true, magnification: 0, pinchesNatively: false).map {
                $0 < 1
            } == true)
        #expect(
            ZoomGestures.factor(type: .scrollWheel, command: false, deltaY: 10, precise: true, magnification: 0, pinchesNatively: false) == nil,
            "a plain scroll scrolls")
        #expect(ZoomGestures.factor(type: .magnify, command: false, deltaY: 0, precise: true, magnification: 0.1, pinchesNatively: false) == 1.1)
        #expect(
            ZoomGestures.factor(type: .magnify, command: false, deltaY: 0, precise: true, magnification: 0.1, pinchesNatively: true) == nil,
            "left to the view")
        #expect(
            ZoomGestures.factor(type: .scrollWheel, command: true, deltaY: 400, precise: true, magnification: 0, pinchesNatively: false) == 1.25,
            "one event zooms at most a quarter")
    }

    @Test func aGestureZoomsAroundThePointer() async throws {
        let (document, zooming) = try await shown()
        defer { document.close() }
        ZoomGestures.zoom(zooming, by: 1.5, at: NSPoint(x: 10, y: 20), in: zooming.contentView)
        #expect(zooming.zoomPercent == 150 && zooming.lastPoint == NSPoint(x: 10, y: 20))
    }
}

extension ZoomControlling {
    /// Found on screen: reading a scroll event's magnification threw, so Cmd+scroll never zoomed.
    @Test func aRealScrollEventIsReadWithoutTouchingMagnification() throws {
        let scroll = try #require(CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: 1, wheel2: 0, wheel3: 0))
        scroll.flags = .maskCommand
        let event = try #require(NSEvent(cgEvent: scroll))
        #expect(ZoomGestures.factor(for: event).map { $0 > 1 } == true)
    }
}
