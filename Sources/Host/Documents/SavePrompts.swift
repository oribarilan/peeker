/// The questions a save may need to ask. Document windows answer with sheets; tests answer directly.
protocol SavePrompts: AnyObject {
    /// The file changed on disk since it was opened or last saved. True to overwrite it.
    func confirmOverwriteNewerFile(named: String) async -> Bool
    /// The file was deleted, renamed or moved since it was opened. True to create it again.
    func confirmRecreateMissingFile(named: String) async -> Bool
    /// The edits can't be written in the file's encoding; `reason` is the plugin's message. True to save as UTF-8.
    func confirmSaveAsUTF8(reason: String) async -> Bool
}

enum SaveOutcome: Equatable {
    case saved
    /// The user declined a prompt. The edits are still pending.
    case cancelled
    /// The edits are still pending; the message says why the save failed.
    case failed(String)
}
