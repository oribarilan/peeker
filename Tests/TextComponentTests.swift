import AppKit
import Testing

@Suite struct TextComponentTests {
    @Test func noteChangesInPlace() {
        let text = TextComponent(text: "a", editable: false, note: "Showing the first 16 MB of 20 MB. Read-only.")
        text.setNote("Showing the first 16 MB of 21 MB. Read-only.")
        #expect(text.note == "Showing the first 16 MB of 21 MB. Read-only.")
    }

    @Test func replacementKeepsZoomAndWrap() throws {
        let old = TextComponent(text: "a", editable: false, note: nil)
        #expect(old.perform("zoom-in") && old.perform("toggle-wrap"))
        let replacement = TextComponent(text: "a", editable: true, note: nil)
        replacement.takeViewState(from: old)
        let view = try #require(replacement.focusView as? NSTextView)
        #expect(view.font?.pointSize == 13)
        #expect(view.textContainer?.widthTracksTextView == false)
    }
}

@Suite struct TextComponentEditingTests {
    @Test func editsAreTheTextThatDiffersFromTheBaseline() {
        let text = TextComponent(text: "a", editable: true, note: nil)
        var edits = 0
        text.onEdit = { edits += 1 }
        #expect(text.pendingEdits() == nil)
        text.restore(.text("b"))
        #expect(edits == 1)
        #expect(text.pendingEdits() == .text("b"))
        text.didSave(.text("b"))
        #expect(text.pendingEdits() == nil)
    }

    /// Typing while a save is in flight isn't on disk, so it stays pending, whoever else asked for the edits meanwhile.
    @Test func didSaveMovesTheBaselineToTheSavedTextOnly() throws {
        let text = TextComponent(text: "a", editable: true, note: nil)
        text.restore(.text("b"))
        let saved = try #require(text.pendingEdits())
        text.restore(.text("c"))
        _ = text.pendingEdits()   // another reader, such as crash recovery
        text.didSave(saved)
        #expect(text.pendingEdits() == .text("c"))
        text.restore(.text("b"))
        #expect(text.pendingEdits() == nil)
    }

    @Test func revertGoesBackToTheBaseline() {
        let text = TextComponent(text: "a", editable: true, note: nil)
        text.restore(.text("b"))
        text.revertEdits()
        #expect(text.pendingEdits() == nil)
    }

    @Test func reloadedTextIsTheNewBaseline() {
        let text = TextComponent(text: "a", editable: true, note: nil)
        text.update(text: "b")
        #expect(text.pendingEdits() == nil)
    }

    /// Canonically equivalent but different code points ("é" vs "e" + combining acute) still count as an edit.
    @Test func equivalentButDifferentTextIsAnEdit() {
        let text = TextComponent(text: "\u{E9}", editable: true, note: nil)
        text.restore(.text("e\u{301}"))
        #expect(text.pendingEdits() == .text("e\u{301}"))
    }
}
