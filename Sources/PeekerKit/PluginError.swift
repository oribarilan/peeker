import Foundation

/// A failure a plugin reports to the user: `message` is shown as is, `code` lets the host react to known cases.
public nonisolated struct PluginError: Error, Sendable, Equatable {
    public enum Code: String, Sendable {
        case general, notText, notWritable, cannotEncode, cancelled
    }

    public let message: String
    public let code: Code
    /// For a failed save: what the user can choose instead.
    public let offer: SaveOffer?

    public init(_ message: String, code: Code = .general, offer: SaveOffer? = nil) {
        self.message = message
        self.code = code
        self.offer = offer
    }

    /// For a plugin to stop early once the host has cancelled the open; the host never shows it.
    public static let cancelled = PluginError("Cancelled.", code: .cancelled)

    /// Runs `body`, turning any other error into a `PluginError` with its description.
    public static func catching<T>(_ body: () throws -> T) throws(PluginError) -> T {
        do {
            return try body()
        } catch {
            throw error as? PluginError ?? PluginError(error.localizedDescription)
        }
    }
}
