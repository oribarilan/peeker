import CoreGraphics
import Foundation
import ImageIO
import PeekerKit
@testable import PeekerImage
import Testing
import UniformTypeIdentifiers

@Suite struct ImagePluginTests {
    /// A `width`×`height` image written as `type`, with an optional EXIF orientation.
    private func image(width: Int, height: Int, type: UTType, orientation: Int? = nil) throws -> URL {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let url = try TempFile.make(Data(), name: "f." + (type.preferredFilenameExtension ?? "img"))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        let properties = orientation.map { [kCGImagePropertyOrientation: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), properties)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    @Test func appliesTheOrientationTag() async throws {
        // Orientation 6: stored landscape, shown rotated a quarter turn, so it appears portrait.
        let url = try image(width: 40, height: 20, type: .jpeg, orientation: 6)
        let decoded = try await ImagePlugin.decode(url, maxPixels: 1000)
        #expect((decoded.image.width, decoded.image.height) == (20, 40))
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
