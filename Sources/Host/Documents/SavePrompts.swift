import PeekerKit

/// The questions a save may need to ask. Document windows answer with sheets; tests answer directly.
protocol SavePrompts: AnyObject {
    /// The file changed on disk since it was opened or last saved. True to overwrite it.
    func confirmOverwriteNewerFile(named: String) async -> Bool
    /// The file was deleted, renamed or moved since it was opened. True to create it again.
    func confirmRecreateMissingFile(named: String) async -> Bool
    /// The save failed with `reason`, and the plugin offers another way, such as saving as UTF-8. True to take it.
    func confirm(_ offer: SaveOffer, reason: String) async -> Bool
}

enum SaveOutcome: Equatable {
    case saved
    /// The user declined a prompt. The edits are still pending.
    case cancelled
    /// The edits are still pending; the message says why the save failed.
    case failed(String)
}
