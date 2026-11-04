import Foundation
import Testing

@Suite struct NavigationHistoryMoves {
    private func entry(_ name: String, place: String? = nil, title: String? = nil, plugin: String = "markdown") -> NavigationHistory.Entry {
        NavigationHistory.Entry(url: URL(filePath: "/docs/\(name)"), pluginID: plugin, place: place, title: title)
    }

    private func names(_ history: NavigationHistory) -> [String] { history.entries.map(\.label) }

    @Test func startsWithOneEntryAndNowhereToGo() {
        let history = NavigationHistory(entry("README.md"))
        #expect(names(history) == ["README.md"])
        #expect(history.index == 0 && !history.canGoBack && !history.canGoForward)
    }

    @Test func pushMovesForward() {
        var history = NavigationHistory(entry("README.md"))
        history.push(entry("README.md", place: "install", title: "Install"))
        history.push(entry("other.md"))
        #expect(names(history) == ["README.md", "Install", "other.md"])
        #expect(history.index == 2 && history.current.label == "other.md" && history.canGoBack && !history.canGoForward)
    }

    @Test func backAndForwardGoSeveralSteps() {
        var history = NavigationHistory(entry("a.md"))
        history.push(entry("b.md"))
        history.push(entry("c.md"))
        let backTwice = history.back() && history.back()
        #expect(backTwice && history.current.label == "a.md")
        let pastTheStart = history.back()
        #expect(!pastTheStart)
        let forward = history.forward()
        #expect(forward)
        #expect(history.current.label == "b.md" && history.canGoForward)
    }

    @Test func aPushAfterBackDropsTheEntriesAhead() {
        var history = NavigationHistory(entry("README.md"))
        history.push(entry("a.md"))
        _ = history.back()
        history.push(entry("b.md"))
        #expect(names(history) == ["README.md", "b.md"])
        #expect(!history.canGoForward)
    }

    @Test func moveGoesToAnyIndex() {
        var history = NavigationHistory(entry("a.md"))
        history.push(entry("b.md"))
        history.push(entry("c.md"))
        history.move(to: 0)
        #expect(history.current.label == "a.md")
        history.move(to: 2)
        #expect(history.current.label == "c.md")
        history.move(to: 7)
        #expect(history.index == 2, "an index outside the history changes nothing")
    }

    @Test func aRecordedPositionComesBackAfterBackThenForward() {
        var history = NavigationHistory(entry("a.md"))
        history.record(42)
        history.push(entry("b.md"))
        history.record(7)
        _ = history.back()
        #expect(history.current.position as? Int == 42)
        _ = history.forward()
        #expect(history.current.position as? Int == 7)
    }

    @Test func openWithReplacesThePluginAndClearsThePosition() {
        var history = NavigationHistory(entry("a.md"))
        history.record(42)
        history.reopened(with: "text")
        #expect(history.current.pluginID == "text" && history.current.position == nil)
    }

    @Test func aTitleArrivesForAnEntry() {
        var history = NavigationHistory(entry("README.md"))
        history.push(entry("other.md", place: "setup"))
        history.setTitle("Setup", at: 1)
        #expect(names(history) == ["README.md", "Setup"])
    }
}
