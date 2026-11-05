import CoreGraphics

/// A color as stored in edits and recovery copies: sRGB components from 0 to 1.
public nonisolated struct RGBA: Codable, Sendable, Equatable {
    public let red, green, blue, alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Within bounds; colors in recovery copies come from a file.
    public var isValid: Bool { [red, green, blue, alpha].allSatisfy { (0...1).contains($0) } }

    public var cgColor: CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
}
