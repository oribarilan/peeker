import AppKit
import PeekerKit
@testable import PeekerImage
import Testing

/// A five-page TIFF whose pages differ in size, open in the Editor.
@MainActor private func pages() async throws -> ImageDocument {
    let url = try multiPageTIFF([(40, 20), (30, 60), (10, 10), (50, 50), (20, 40)])
    return try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, editing: true, maxPixels: 1000)
}

@MainActor private func show(_ tool: String, in document: ImageDocument) async {
    #expect(document.perform(tool))
    await document.pageChange?.value
}

@Suite(.serialized) struct ImagePages {
    @Test func onlyAMultiPageTIFFHasPageTools() async throws {
        let document = try await pages()
        #expect(document.tools.map(\.id).contains("next-page") && document.tools.map(\.id).contains("previous-page"))
        let single = try await openDocument(try imageFile(try cornerImage(), type: .tiff), with: ImagePlugin.self, as: ImageDocument.self,
                                            editing: true, maxPixels: 1000)
        #expect(!single.tools.map(\.id).contains("next-page"))
    }

    @Test func nextPageShowsTheNextPageAndItsDetails() async throws {
        let document = try await pages()
        var sidebarChanges = 0
        document.onSidebarChange = { sidebarChanges += 1 }
        await show("next-page", in: document)
        #expect(document.page == 1)
        #expect(document.shownSize == CGSize(width: 30, height: 60))
        #expect(document.info.first == InfoRow(label: "Page", value: "2 of 5"))
        #expect(sidebarChanges == 1)
        await show("previous-page", in: document)
        #expect(document.page == 0 && document.shownSize == CGSize(width: 40, height: 20))
    }

    @Test func thereIsNoPageBeforeTheFirstOrAfterTheLast() async throws {
        let document = try await pages()
        #expect(document.unavailableReason(for: "previous-page") != nil)
        #expect(document.unavailableReason(for: "next-page") == nil)
        for _ in 0..<4 { await show("next-page", in: document) }
        #expect(document.page == 4)
        #expect(document.unavailableReason(for: "next-page") != nil)
        #expect(document.unavailableReason(for: "previous-page") == nil)
    }

    @Test func thePageKeysAreViewToolsOnPageUpAndDown() {
        let next = ImagePlugin.tools.first { $0.id == "next-page" }, previous = ImagePlugin.tools.first { $0.id == "previous-page" }
        #expect(next?.shortcut == "pagedown" && previous?.shortcut == "pageup")
        #expect(next?.isEditTool == false && next?.showsInToolbar == false)
    }

    @Test func aPageChangeKeepsTheZoom() async throws {
        let document = try await pages()
        let window = offscreenWindow(holding: document.contentView, width: 400, height: 300)
        defer { window.close() }
        let scroll = try #require(document.contentView as? NSScrollView)
        await show("next-page", in: document)
        #expect(scroll.magnification == 1)
        #expect(document.perform("zoom-in"))
        #expect(document.perform("zoom-in"))
        let zoomed = scroll.magnification
        await show("next-page", in: document)
        #expect(abs(scroll.magnification - zoomed) < 0.001)
        let shown = scroll.contentView.bounds, image = document.canvas.imageRect
        #expect(abs(shown.minX - image.minX) < 1 && abs(shown.maxY - image.maxY) < 1, "scrolled to the page's top left")
    }
}

@Suite(.serialized) struct ImagePageList {
    @Test func aRowPerPageWithTheShownOneSelected() async throws {
        let list = try #require(try await pages().pageList)
        #expect(list.table.numberOfRows == 5)
        #expect(list.table.selectedRow == 0)
    }

    @Test func selectingARowShowsThatPage() async throws {
        let document = try await pages()
        let list = try #require(document.pageList)
        list.table.selectRowIndexes([3], byExtendingSelection: false)
        await document.pageChange?.value
        #expect(document.page == 3 && document.shownSize == CGSize(width: 50, height: 50))
    }

    @Test func thePageToolsMoveTheSelection() async throws {
        let document = try await pages()
        await show("next-page", in: document)
        #expect(document.pageList?.table.selectedRow == 1)
    }

    @Test func theListIsAboveTheInfoAndOnlyForPages() async throws {
        let document = try await pages()
        let sidebar = document.makeSidebar()
        #expect(sidebar.count == 2 && sidebar.first?.view === document.pageList && sidebar.first?.sizing == .fill)
        #expect(document.makeSidebar().first?.view === sidebar.first?.view, "the same list each time, so it keeps its place")
        let single = try await openDocument(try imageFile(try cornerImage(), type: .tiff), with: ImagePlugin.self, as: ImageDocument.self,
                                            editing: true, maxPixels: 1000)
        #expect(single.pageList == nil && single.makeSidebar().count == 1)
    }

    @Test func thumbnailsAreSmallDecodesOfEachPage() async throws {
        let list = try #require(try await pages().pageList)
        let thumbnail = try #require(await list.thumbnail(of: 1))
        #expect(max(thumbnail.width, thumbnail.height) <= PageList.thumbnailSide)
        #expect(thumbnail.height == 2 * thumbnail.width, "the second page is 30 × 60")
    }
}

@Suite(.serialized) struct ImagePagePrinting {
    @Test func everyPagePrintsOnASheetOfItsOwn() async throws {
        let url = try multiPageTIFF([(40, 20), (30, 60), (2000, 1000)])
        let document = try await openDocument(url, with: ImagePlugin.self, as: ImageDocument.self, editing: true, maxPixels: 4000)
        document.showPage(1)
        await document.pageChange?.value
        let info = NSPrintInfo()
        let operation = try #require(document.printJob?(info))
        let view = try #require(operation.view as? PagesPrintView)
        #expect(info.orientation == .landscape, "from the first page, 40 × 20")
        var range = NSRange()
        #expect(view.knowsPageRange(&range) && range == NSRange(location: 1, length: 3))
        let sheet = view.rectForPage(2)
        #expect(sheet.size == info.imageablePageBounds.size)
        // Own size in points (no resolution: one point per pixel), centered, never enlarged.
        let small = view.pictureRect(forPage: 2)
        #expect(small.size == CGSize(width: 30, height: 60))
        #expect(abs(small.midX - sheet.midX) < 0.5 && abs(small.midY - sheet.midY) < 0.5)
        // Shrunk to fit when larger than the sheet.
        let large = view.pictureRect(forPage: 3)
        #expect(large.width <= sheet.width + 0.5 && large.height <= sheet.height + 0.5)
        #expect(abs(large.width / large.height - 2) < 0.01)
    }

    @Test func aSingleImagePrintsAsBefore() async throws {
        let document = try await openDocument(try imageFile(try cornerImage(), type: .png), with: ImagePlugin.self, as: ImageDocument.self,
                                              editing: true, maxPixels: 1000)
        #expect(document.printJob?(NSPrintInfo())?.view is NSImageView)
    }
}

