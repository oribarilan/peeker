import Testing

@Suite struct MenuBarItemTests {
    @Test func problemsLineCountsInWords() {
        #expect(MenuBarItem.problemsTitle(count: 1) == "Config has 1 problem")
        #expect(MenuBarItem.problemsTitle(count: 3) == "Config has 3 problems")
    }
}
