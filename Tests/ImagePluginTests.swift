import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PeekerKit
@testable import PeekerImage
import Testing
import UniformTypeIdentifiers

@Suite struct ImagePluginTests {
    /// A `width`×`height` image written as `type`, with an optional EXIF orientation.
    private func image(width: Int, height: Int, type: UTType, orientation: Int? = nil, dpi: Double? = nil) throws -> URL {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let url = try TempFile.make(Data(), name: "f." + (type.preferredFilenameExtension ?? "img"))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        var properties: [CFString: Any] = [:]
        if let orientation { properties[kCGImagePropertyOrientation] = orientation }
        if let dpi { properties[kCGImagePropertyDPIWidth] = dpi; properties[kCGImagePropertyDPIHeight] = dpi }
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test func appliesTheOrientationTag() async throws {
        // Orientation 6: stored landscape, shown rotated a quarter turn, so it appears portrait.
        let url = try image(width: 40, height: 20, type: .jpeg, orientation: 6)
        let decoded = try await ImagePlugin.decode(url, maxPixels: 1000)
        #expect((decoded.image.width, decoded.image.height) == (20, 40))
    }

    @Test func printSizeIsInPointsFromTheResolutionAndUpright() async throws {
        let plain = try await ImagePlugin.decode(try image(width: 400, height: 200, type: .png), maxPixels: 100)
        #expect(plain.printSize == CGSize(width: 400, height: 200))
        let dense = try await ImagePlugin.decode(try image(width: 400, height: 200, type: .png, dpi: 144), maxPixels: 100)
        #expect(dense.printSize == CGSize(width: 200, height: 100))
        let turned = try await ImagePlugin.decode(try image(width: 40, height: 20, type: .jpeg, orientation: 6), maxPixels: 100)
        #expect(turned.printSize == CGSize(width: 20, height: 40))
    }

    @Test func printStartsInTheImagesOrientation() async throws {
        let wide = try await ImagePlugin.open(try image(width: 400, height: 200, type: .png), context: OpenContext(maxPixels: 100, allowsEditing: true))
        let tall = try await ImagePlugin.open(try image(width: 200, height: 400, type: .png), context: OpenContext(maxPixels: 100, allowsEditing: true))
        let wideJob = try #require(wide.printJob), tallJob = try #require(tall.printJob)
        #expect(wideJob(NSPrintInfo())?.printInfo.orientation == .landscape)
        #expect(tallJob(NSPrintInfo())?.printInfo.orientation == .portrait)
    }

    /// Fit pagination shrinks a view that's too big for the page and never enlarges one.
    @Test func aSmallImagePrintsAtItsOwnSizeAndALargeOneFitsThePage() async throws {
        func redArea(width: Int, height: Int) async throws -> (pixels: Int, page: CGSize) {
            let document = try await ImagePlugin.open(try image(width: width, height: height, type: .png), context: OpenContext(maxPixels: 100, allowsEditing: true))
            let job = try #require(document.printJob)
            let page = try #require(try printed(job, title: "f.png").page(at: 0))
            let size = page.bounds(for: .mediaBox).size
            let context = try #require(CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                                                 space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(origin: .zero, size: size))
            page.draw(with: .mediaBox, to: context)
            let pixels = try #require(context.data).bindMemory(to: UInt8.self, capacity: context.bytesPerRow * context.height)
            var red = 0
            for y in 0..<context.height {
                for x in 0..<context.width {
                    let p = pixels + y * context.bytesPerRow + x * 4
                    if p[0] > 200 && p[1] < 60 && p[2] < 60 { red += 1 }
                }
            }
            return (red, size)
        }
        let icon = try await redArea(width: 64, height: 64)
        #expect(abs(icon.pixels - 64 * 64) < 300, "printed at 64 × 64 points, not enlarged")
        let photo = try await redArea(width: 4000, height: 3000)
        #expect(photo.page.width > photo.page.height, "landscape")
        #expect(photo.pixels > Int(photo.page.width * photo.page.height) / 2, "fills most of the page")
        #expect(photo.pixels < Int(photo.page.width * photo.page.height), "inside the margins")
    }

    @Test func decodesNoLargerThanTheScreenNeeds() async throws {
        let url = try image(width: 400, height: 200, type: .png)
        let decoded = try await ImagePlugin.decode(url, maxPixels: 100)
        #expect(max(decoded.image.width, decoded.image.height) == 100)
    }

    @Test func infoListsTheFullDimensions() async throws {
        let url = try image(width: 400, height: 200, type: .png)
        let decoded = try await ImagePlugin.decode(url, maxPixels: 100)
        #expect(decoded.info.contains(PeekerKit.InfoRow(label: "Dimensions", value: "400 × 200")))
    }

    @Test func corruptFileSaysItIsNotAReadableImage() async throws {
        let url = try TempFile.make(Data("not an image".utf8), name: "f.png")
        await #expect(throws: PluginError("This file isn't a readable image.")) {
            _ = try await ImagePlugin.open(url, context: OpenContext(maxPixels: 100, allowsEditing: false))
        }
    }

    @Test func documentOffersZoomCommands() async throws {
        let url = try image(width: 40, height: 20, type: .png)
        let document = try await ImagePlugin.open(url, context: OpenContext(maxPixels: 100, allowsEditing: false))
        #expect(document.commands.map(\.id) == ["zoom-in", "zoom-out", "zoom-fit"])
        #expect(document.perform("zoom-in"))
        #expect(!document.perform("no-such-command"))
    }
}
