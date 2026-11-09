import CommonCrypto
import CryptoKit
import Foundation
import os

/// A password-protected PDF's crash-recovery copy: its edits encrypted with AES-GCM under a key made from the
/// password that unlocked it, so the copy can't be read without that password.
nonisolated struct SealedEdits: Codable, Sendable, Equatable {
    /// The AES-GCM nonce, ciphertext and tag together.
    let sealed: Data
    let salt: Data
}

/// The key for a password-protected PDF's recovery copies, made from its password with PBKDF2-HMAC-SHA256 the first
/// time it's needed (about half a second, on the recovery store's queue, or at unlocking when there's a copy to open),
/// then kept in memory with the password.
nonisolated final class RecoveryKey: Sendable {
    let salt: Data
    private let password: String
    private let key = OSAllocatedUnfairLock<SymmetricKey?>(initialState: nil)
    private static let rounds: UInt32 = 600_000

    init(password: String, salt: Data? = nil) {
        self.password = password
        self.salt = salt ?? Data((0..<16).map { _ in UInt8.random(in: 0...255) })
    }

    func seal(_ json: Data) throws -> SealedEdits {
        guard let combined = try AES.GCM.seal(json, using: derived()).combined else { throw CocoaError(.coderInvalidValue) }
        return SealedEdits(sealed: combined, salt: salt)
    }

    /// The edits in `sealed`, or nil when it wasn't sealed with this password and salt.
    func open(_ sealed: SealedEdits) -> Data? {
        guard sealed.salt == salt, let box = try? AES.GCM.SealedBox(combined: sealed.sealed) else { return nil }
        return try? AES.GCM.open(box, using: derived())
    }

    private func derived() -> SymmetricKey {
        key.withLock { stored in
            if let stored { return stored }
            var bytes = [UInt8](repeating: 0, count: 32)
            let utf8 = Array(password.utf8)
            let status = salt.withUnsafeBytes { salt in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), utf8.map { CChar(bitPattern: $0) }, utf8.count,
                                     salt.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), Self.rounds, &bytes, bytes.count)
            }
            precondition(status == kCCSuccess, "PBKDF2 failed")  // only fails on bad arguments, which these aren't
            let made = SymmetricKey(data: bytes)
            stored = made
            return made
        }
    }
}
