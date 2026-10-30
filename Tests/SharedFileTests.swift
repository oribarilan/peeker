import CoreGraphics
import Foundation
import Testing

@Suite struct SharedFileTests {
    @Test func createThenMapReturnsTheBytesAndRemovesTheName() throws {
        let ref = try SharedFile.create(Data("hello".utf8))
        let mapped = try SharedFile.map(ref)
        #expect(Data(mapped.bytes) == Data("hello".utf8))
        #expect(!FileManager.default.fileExists(atPath: ref.path))
    }

    @Test func withMappedReadsTheBytesAndRemovesTheName() throws {
        let ref = try SharedFile.create(Data("scoped".utf8))
        #expect(try SharedFile.withMapped(ref) { String(decoding: $0, as: UTF8.self) } == "scoped")
        #expect(!FileManager.default.fileExists(atPath: ref.path))
    }

    @Test func withMappedHandlesAnEmptyFile() throws {
        #expect(try SharedFile.withMapped(try SharedFile.create(Data())) { $0.count } == 0)
    }

    @Test func refusesPathsOutsideTheTempDirectory() {
        #expect(throws: PluginFailure.self) { try SharedFile.map(SharedFileRef(path: "/etc/hosts", byteCount: 1)) }
    }

    @Test func refusesAByteCountLargerThanTheFile() throws {
        let ref = try SharedFile.create(Data("hi".utf8))
        #expect(throws: PluginFailure.self) { try SharedFile.map(SharedFileRef(path: ref.path, byteCount: 4096)) }
    }

    @Test func refusesSymlinks() throws {
        let link = FileManager.default.temporaryDirectory.appending(path: SharedFile.prefix + UUID().uuidString)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "/etc/hosts")
        defer { try? FileManager.default.removeItem(at: link) }
        #expect(throws: PluginFailure.self) { try SharedFile.map(SharedFileRef(path: link.path, byteCount: 1)) }
    }
}

extension SharedFileTests {
    @Test func discardRemovesASharedFile() throws {
        let ref = try SharedFile.create(Data("unread".utf8))
        SharedFile.discard(ref)
        #expect(!FileManager.default.fileExists(atPath: ref.path))
    }

    @Test func discardLeavesFilesWithoutTheSharedPrefixAlone() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "not-shared-" + UUID().uuidString)
        try Data("keep".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        SharedFile.discard(SharedFileRef(path: url.path, byteCount: 4))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func refusesAFifoWithoutBlocking() throws {
        let path = FileManager.default.temporaryDirectory.appending(path: SharedFile.prefix + UUID().uuidString).path
        #expect(mkfifo(path, 0o600) == 0)
        defer { unlink(path) }
        #expect(throws: PluginFailure.self) { try SharedFile.map(SharedFileRef(path: path, byteCount: 1)) }
    }

    @Test func worksOffTheMainActor() async throws {
        try await Task.detached {
            let ref = try SharedFile.create(Data("off main".utf8))
            #expect(try SharedFile.withMapped(ref) { Data($0) } == Data("off main".utf8))
            let request = Request(id: 1, doc: "d", call: .close)
            let decoded = try JSONDecoder().decode(Request.self, from: JSONEncoder().encode(request))
            #expect(decoded.id == 1)
        }.value
    }
}

@Suite struct SharedBitmapTests {
    @Test func writtenPixelsReadBackWithoutDecoding() throws {
        let context = try #require(CGContext(data: nil, width: 3, height: 2, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 2))
        let bitmap = try SharedBitmap.write(try #require(context.makeImage()))
        let image = try SharedBitmapReader.image(from: bitmap)
        #expect((image.width, image.height) == (3, 2))
        let bytes = try #require(image.dataProvider?.data as Data?)
        #expect(Array(bytes.prefix(4)) == [0, 0, 255, 255])  // BGRA
    }

    @Test func refusesRowsTooShortForTheWidth() throws {
        let file = try SharedFile.create(Data(count: 64))
        #expect(throws: PluginFailure.self) { try SharedBitmapReader.image(from: SharedBitmap(file: file, width: 8, height: 2, bytesPerRow: 16)) }
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }
}
