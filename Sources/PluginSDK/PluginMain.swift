import CoreGraphics
import Foundation

/// What a plugin implements. Each call gets the document id the host assigned to one open tab.
protocol PluginHandler {
    func open(_ doc: DocumentID, path: String, maxPixels: Int) throws(PluginFailure) -> Reply
    func command(_ doc: DocumentID, id: String, args: [String: Int]) throws(PluginFailure) -> Reply
    func save(_ doc: DocumentID, _ payload: SavePayload) throws(PluginFailure) -> Reply
    func close(_ doc: DocumentID)
}

extension PluginHandler {
    func command(_ doc: DocumentID, id: String, args: [String: Int]) throws(PluginFailure) -> Reply {
        throw PluginFailure("unknown command \(id)")
    }

    func save(_ doc: DocumentID, _ payload: SavePayload) throws(PluginFailure) -> Reply {
        throw PluginFailure("This plugin can't save.")
    }

    func close(_ doc: DocumentID) {}
}

enum PluginMain {
    /// Serves requests until the host closes stdin, then exits.
    // Takes an existential on purpose: specializing this for a concrete handler crashed the Swift 6.4
    // optimizer (SimplifyCFG) in whole-module Release builds.
    static func run(_ handler: any PluginHandler) -> Never {
        let decoder = JSONDecoder(), encoder = JSONEncoder()
        while let line = readLine(strippingNewline: true) {
            guard var data = response(to: line, handler, decoder, encoder) else { continue }
            data.append(0x0A)
            do {
                try FileHandle.standardOutput.write(contentsOf: data)
            } catch {
                exit(1)  // the host is gone
            }
        }
        exit(0)
    }

    /// The reply line (without its newline) for one request line; nil for `close`, which gets none, and for a line
    /// so broken it has no id to answer.
    static func response(to line: String, _ handler: any PluginHandler, _ decoder: JSONDecoder, _ encoder: JSONEncoder) -> Data? {
        let request: Request
        do {
            request = try decoder.decode(Request.self, from: Data(line.utf8))
        } catch {
            guard let id = try? decoder.decode(RequestID.self, from: Data(line.utf8)).id else {
                FileHandle.standardError.write(Data("unreadable request without an id: \(error)\n".utf8))
                return nil
            }
            return encode(Response(id: id, outcome: .failure(PluginFailure("unreadable request: \(error)"))), encoder)
        }
        let outcome: Outcome
        do throws(PluginFailure) {
            switch request.call {
            case .open(let path, let maxPixels): outcome = .reply(try handler.open(request.doc, path: path, maxPixels: maxPixels))
            case .command(let id, let args): outcome = .reply(try handler.command(request.doc, id: id, args: args))
            case .save(let payload): outcome = .reply(try handler.save(request.doc, payload))
            case .close:
                handler.close(request.doc)
                return nil
            }
        } catch {
            outcome = .failure(error)
        }
        return encode(Response(id: request.id, outcome: outcome), encoder)
    }

    private struct RequestID: Decodable { let id: Int }

    private static func encode(_ response: Response, _ encoder: JSONEncoder) -> Data {
        do {
            return try encoder.encode(response)
        } catch {
            // Only a reply that can't be encoded gets here (a non-finite number, say).
            do {
                return try encoder.encode(Response(id: response.id, outcome: .failure(PluginFailure("could not encode reply: \(error)"))))
            } catch {
                return fallbackFailure(id: response.id)
            }
        }
    }
}

extension PluginMain {
    /// A failure response that needs no encoder, so the host always gets a line it can read.
    static func fallbackFailure(id: Int) -> Data {
        Data(#"{"id":\#(id),"outcome":{"failure":{"_0":{"message":"could not encode reply","code":"general"}}}}"#.utf8)
    }
}

extension PluginFailure {
    /// Runs `body`, turning any error it throws into a failure that carries the error's description.
    static func catching<T>(_ body: () throws -> T) throws(PluginFailure) -> T {
        do {
            return try body()
        } catch {
            throw error as? PluginFailure ?? PluginFailure(error.localizedDescription)
        }
    }
}

extension SharedBitmap {
    /// Draws `image` into a new shared file the host can display without decoding anything itself.
    static func write(_ image: CGImage) throws(PluginFailure) -> SharedBitmap {
        let width = image.width, height = image.height
        let bytesPerRow = (width * 4 + 63) & ~63
        let file = try SharedFile.create(byteCount: bytesPerRow * height) { buffer in
            let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info) else {
                throw PluginFailure("could not create bitmap context")
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return SharedBitmap(file: file, width: width, height: height, bytesPerRow: bytesPerRow)
    }
}
