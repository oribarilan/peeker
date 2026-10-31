import CoreGraphics
import Foundation
import ImageIO
import PeekerKit
@testable import PeekerImage
import Testing
import UniformTypeIdentifiers

@Suite struct ImageEdits {
    @Test func rotateTurnsClockwiseAndBack() throws {
        let image = try cornerImage()
        let right = try #require(ImageEditing.apply([.rotate(by: 90)], to: image))
        #expect((right.width, right.height) == (20, 40))
        #expect(try corners(right) == ["blue", "red", "white", "green"])
        let left = try #require(ImageEditing.apply([.rotate(by: -90)], to: image))
        #expect(try corners(left) == ["green", "white", "red", "blue"])
    }

    @Test func flipsMirror() throws {
        let image = try cornerImage()
        #expect(try corners(try #require(ImageEditing.apply([.flip(horizontal: true)], to: image))) == ["green", "red", "white", "blue"])
        #expect(try corners(try #require(ImageEditing.apply([.flip(horizontal: false)], to: image))) == ["blue", "white", "red", "green"])
    }

    @Test func cropTakesTheRectFromTheTopLeft() throws {
        let image = try cornerImage()
        let left = try #require(ImageEditing.apply([.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1))], to: image))
        #expect((left.width, left.height) == (20, 20))
        #expect(try corners(left) == ["red", "black", "blue", "black"])
        let topRight = try #require(ImageEditing.apply([.crop(CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))], to: image))
        #expect((topRight.width, topRight.height) == (20, 10))
        #expect(try corners(topRight)[1] == "green")
    }

    @Test func resizeScalesAndKeepsDepth() throws {
        let image = try cornerImage(bits: 16)
        let resized = try #require(ImageEditing.apply([.resize(width: 80, height: 40)], to: image))
        #expect((resized.width, resized.height) == (80, 40))
        #expect(resized.bitsPerComponent == 16)
    }

    @Test func editsApplyInOrderAndSizeFollows() throws {
        let edits: [ImageEdit] = [.rotate(by: 90), .crop(CGRect(x: 0, y: 0, width: 1, height: 0.5)), .resize(width: 10, height: 10)]
        #expect(ImageEditing.size(after: edits, from: CGSize(width: 40, height: 20)) == CGSize(width: 10, height: 10))
        #expect(ImageEditing.size(after: Array(edits.prefix(2)), from: CGSize(width: 40, height: 20)) == CGSize(width: 20, height: 20))
        let image = try #require(ImageEditing.apply(Array(edits.prefix(2)), to: try cornerImage()))
        #expect(try corners(image) == ["blue", "red", "black", "black"])
    }

    /// The window shows a screen-size decode: a resize scales it by the same factor as the full image, and never past
    /// the decode's own size, so enlarging stays cheap.
    @Test func thePreviewScalesTheScreenDecodeAndCapsEnlarging() throws {
        let decode = try cornerImage(width: 200, height: 100)
        let full = CGSize(width: 400, height: 200)
        let half = ImageEditing.preview([.resize(width: 200, height: 100)], of: decode, fullSize: full)
        #expect(half.width == 100 && half.height == 50)
        let doubled = ImageEditing.preview([.resize(width: 800, height: 400)], of: decode, fullSize: full)
        #expect(doubled.width == 200 && doubled.height == 100)
        let turned = ImageEditing.preview([.rotate(by: 90), .resize(width: 100, height: 200)], of: decode, fullSize: full)
        #expect(turned.width == 50 && turned.height == 100)
    }

    @Test func onlyQuarterTurnsCropsInsideAndSaneSizesAreValid() throws {
        #expect(ImageEdit.rotate(by: 90).isValid && !ImageEdit.rotate(by: 45).isValid)
        #expect(ImageEdit.crop(CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)).isValid)
        #expect(!ImageEdit.crop(CGRect(x: 0.6, y: 0, width: 0.5, height: 1)).isValid)
        #expect(!ImageEdit.crop(CGRect(x: 0, y: 0, width: 0, height: 1)).isValid)
        #expect(ImageEdit.resize(width: 1, height: 1).isValid && !ImageEdit.resize(width: 0, height: 5).isValid)
        #expect(!ImageEdit.resize(width: 100_000, height: 5).isValid)
        let json = try JSONEncoder().encode([ImageEdit.rotate(by: -90), .flip(horizontal: true), .crop(CGRect(x: 0, y: 0, width: 1, height: 1)), .resize(width: 3, height: 4)])
        #expect(try JSONDecoder().decode([ImageEdit].self, from: json).count == 4)
    }
}

@Suite struct ImageSavingTests {
    private let exif: [CFString: Any] = [kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:31 09:00:00"]]

    @Test func rotationAloneKeepsAJPEGsImageDataAndSetsItsOrientation() async throws {
        let url = try imageFile(try cornerImage(), type: .jpeg, properties: exif)
        let before = try stored(url)
        try await ImageSaving.save([.rotate(by: 90)], to: url.path)
        let after = try stored(url)
        #expect(after.properties[kCGImagePropertyOrientation] as? Int == 6)
        #expect((after.image.width, after.image.height) == (40, 20))
        #expect(pixels(after.image) == pixels(before.image), "not re-encoded")
        try await ImageSaving.save([.rotate(by: 90), .flip(horizontal: true)], to: url.path)
        #expect(try stored(url).properties[kCGImagePropertyOrientation] as? Int == 4, "6, then 90 more and a mirror")
    }

    @Test func aCropSavesAtFullSizeWithItsMetadata() async throws {
        let url = try imageFile(try cornerImage(width: 400, height: 300), type: .jpeg, properties: exif)
        try await ImageSaving.save([.crop(CGRect(x: 0, y: 0, width: 0.5, height: 1))], to: url.path)
        let after = try stored(url)
        #expect((after.image.width, after.image.height) == (200, 300))
        #expect(after.type == UTType.jpeg.identifier)
        let saved = after.properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(saved?[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:10:31 09:00:00")
        #expect(try corners(after.image)[0] == "red")
    }

    @Test func aSixteenBitPNGStaysSixteenBit() async throws {
        let url = try imageFile(try cornerImage(bits: 16), type: .png)
        try await ImageSaving.save([.rotate(by: 90), .crop(CGRect(x: 0, y: 0, width: 1, height: 0.5))], to: url.path)
        let after = try stored(url)
        #expect(after.image.bitsPerComponent == 16)
        #expect((after.image.width, after.image.height) == (20, 20))
        #expect(try corners(after.image) == ["blue", "red", "black", "black"])
    }

    @Test func anOrientedPhotoIsCroppedAsItLooks() async throws {
        // Stored 40 × 20, shown turned clockwise (orientation 6), so it looks 20 × 40 with blue at the top left.
        let url = try imageFile(try cornerImage(), type: .jpeg, properties: [kCGImagePropertyOrientation: 6])
        try await ImageSaving.save([.crop(CGRect(x: 0, y: 0, width: 1, height: 0.5))], to: url.path)
        let after = try stored(url)
        #expect((after.image.width, after.image.height) == (20, 20))
        #expect((after.properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        #expect(try corners(after.image) == ["blue", "red", "black", "black"])
    }

    @Test func aFileThatIsNoLongerAnImageIsNotWritten() async throws {
        let url = try TempFile.make(Data("not an image".utf8), name: "f.png")
        await #expect(throws: PluginError.self) { try await ImageSaving.save([.rotate(by: 90)], to: url.path) }
        #expect(try Data(contentsOf: url) == Data("not an image".utf8))
    }
}

@Suite struct ImageHDRSaving {
    /// A 400 × 300 HEIC whose brightness runs from 0 to 4 times SDR white left to right, saved with an ISO gain map.
    private func hdrFile() throws -> URL {
        let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue
        let context = try #require(CGContext(data: nil, width: 400, height: 300, bitsPerComponent: 16, bytesPerRow: 0, space: space, bitmapInfo: info))
        for x in 0..<400 {
            let v = CGFloat(x) / 399 * 4
            context.setFillColor(CGColor(colorSpace: space, components: [v, v * 0.9, v * 0.8, 1])!)
            context.fill(CGRect(x: x, y: 0, width: 1, height: 300))
        }
        return try imageFile(try #require(context.makeImage()), type: .heic,
                             properties: [kCGImageDestinationEncodeRequest: kCGImageDestinationEncodeToISOGainmap, kCGImageDestinationLossyCompressionQuality: 0.9])
    }

    private func hasGainMap(_ url: URL) throws -> Bool {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeISOGainMap) != nil
    }

    @Test func aCropKeepsTheGainMap() async throws {
        let url = try hdrFile()
        #expect(try hasGainMap(url))
        try await ImageSaving.save([.crop(CGRect(x: 0.5, y: 0, width: 0.5, height: 1))], to: url.path)
        #expect(try hasGainMap(url))
        #expect(try stored(url).image.width == 200)
    }

    @Test func aRotationKeepsTheGainMap() async throws {
        let url = try hdrFile()
        try await ImageSaving.save([.rotate(by: 90)], to: url.path)
        #expect(try hasGainMap(url))
    }
}

private func pixels(_ image: CGImage) -> Data? {
    image.dataProvider?.data as Data?
}
