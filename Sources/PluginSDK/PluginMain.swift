import CoreGraphics
import Foundation

/// What a plugin implements. Each call gets the document id the host assigned to one open tab.
protocol PluginHandler {
    func open(doc: String, path: String, params: [String: Any]) throws -> [String: Any]
    func command(doc: String, id: String, args: [String: Any]) throws -> [String: Any]
    func close(doc: String)
}

struct PluginFailure: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

enum PluginMain {
    /// Serves requests until the host closes stdin, then exits.
    // Takes an existential on purpose: specializing this for a concrete handler crashed the Swift 6.4
    // optimizer (SimplifyCFG) in whole-module Release builds.
    static func run(_ handler: any PluginHandler) -> Never {
        while let line = readLine(strippingNewline: true) {
            serve(line, handler)
        }
        exit(0)
    }

    private static func serve(_ line: String, _ handler: any PluginHandler) {
        guard let request = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
              let method = request["method"] as? String else { return }
        let params = request["params"] as? [String: Any] ?? [:]
        let doc = params["doc"] as? String ?? ""
        let id = request["id"] ?? 0
        do {
            switch method {
            case "open":
                guard let path = params["path"] as? String else { throw PluginFailure("open needs a path") }
                reply(["id": id, "result": try handler.open(doc: doc, path: path, params: params)])
            case "command":
                guard let command = params["command"] as? String else { throw PluginFailure("command needs an id") }
                reply(["id": id, "result": try handler.command(doc: doc, id: command, args: params["args"] as? [String: Any] ?? [:])])
            case "close":
                handler.close(doc: doc)
            default:
                throw PluginFailure("unknown method \(method)")
            }
        } catch let failure as PluginFailure {
            reply(["id": id, "error": failure.message])
        } catch {
            reply(["id": id, "error": error.localizedDescription])
        }
    }

    private static func reply(_ message: [String: Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject: message) else { return }
        data.append(0x0A)
        FileHandle.standardOutput.write(data)
    }
}

enum SharedBitmap {
    /// Draws `image` into a new mapped file the host can display without decoding anything itself.
    static func write(_ image: CGImage) throws -> [String: Any] {
        let width = image.width, height = image.height
        let bytesPerRow = (width * 4 + 63) & ~63
        let size = bytesPerRow * height
        let url = FileManager.default.temporaryDirectory.appending(path: "\(SharedBitmapFormat.prefix)\(UUID().uuidString)")
        let fd = Darwin.open(url.path, O_CREAT | O_EXCL | O_RDWR, 0o600)
        guard fd >= 0 else { throw PluginFailure("could not create bitmap file") }
        defer { Darwin.close(fd) }
        guard ftruncate(fd, off_t(size)) == 0,
              let memory = mmap(nil, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0), memory != MAP_FAILED else {
            unlink(url.path)
            throw PluginFailure("could not map bitmap file")
        }
        defer { munmap(memory, size) }
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(data: memory, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info) else {
            unlink(url.path)
            throw PluginFailure("could not create bitmap context")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ["type": "bitmap", "file": url.path, "width": width, "height": height, "bytesPerRow": bytesPerRow]
    }
}
