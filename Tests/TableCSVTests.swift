import Foundation
@testable import PeekerTable
import Testing

private func table(_ text: String, _ delimiter: Delimiter = .comma) -> CSVTable { CSVTable(text: text, delimiter: delimiter) }
private func cells(_ table: CSVTable) -> [[String]] {
    (0..<table.rowCount).map { row in (0..<table.columnCount).map { table.cell(row: row, column: $0) } }
}

@Suite struct CSVReading {
    @Test func plainFields() {
        let t = table("a,b,c\n1,2,3\n")
        #expect(t.rowCount == 2 && t.columnCount == 3)
        #expect(cells(t) == [["a", "b", "c"], ["1", "2", "3"]])
    }

    @Test func quotedFieldsKeepDelimitersQuotesAndLineBreaks() {
        let t = table("name,note\n\"Smith, Jane\",\"said \"\"hi\"\"\"\n\"two\nlines\",x\n")
        #expect(cells(t) == [["name", "note"], ["Smith, Jane", "said \"hi\""], ["two\nlines", "x"]])
        #expect(t.fields(ofRow: 1).map(\.quoted) == [true, true])
    }

    @Test func raggedRowsPadWithEmptyCells() {
        let t = table("a,b,c\n1,2,3,4,5\nx\n")
        #expect(t.columnCount == 5)
        #expect(cells(t)[0] == ["a", "b", "c", "", ""] && cells(t)[2] == ["x", "", "", "", ""])
    }

    @Test func aStrayQuoteIsText() {
        #expect(cells(table("5\" pipe,ok\n")) == [["5\" pipe", "ok"]])
    }

    @Test func aMissingClosingQuoteRunsToTheEnd() {
        let t = table("a,\"open\nstill open")
        #expect(t.rowCount == 1 && t.cell(row: 0, column: 1) == "open\nstill open")
    }

    @Test func crlfAndNoFinalLineBreak() {
        #expect(cells(table("a,b\r\n1,2")) == [["a", "b"], ["1", "2"]])
    }

    @Test func emptyFieldsAndAnEmptyFile() {
        #expect(cells(table(",,\n")) == [["", "", ""]])
        #expect(table("").rowCount == 0 && table("").columnCount == 0)
    }

    @Test func otherDelimiters() {
        #expect(cells(table("a;b\n3,50;x\n", .semicolon)) == [["a", "b"], ["3,50", "x"]])
        #expect(cells(table("a\tb\n", .tab)) == [["a", "b"]])
        #expect(cells(table("a|b\n", .pipe)) == [["a", "b"]])
    }
}

@Suite struct CSVGuesses {
    @Test func theDelimiterIsTheOneEveryLineAgreesOn() {
        #expect(CSVTable.guessDelimiter(in: "name;price\nTea;3,50\nCake;4,20\n") == .semicolon)
        #expect(CSVTable.guessDelimiter(in: "a,b,c\n1,2,3\n") == .comma)
        #expect(CSVTable.guessDelimiter(in: "a\tb\n1\t2\n") == .tab)
        #expect(CSVTable.guessDelimiter(in: "a|b\n1|2\n") == .pipe)
        #expect(CSVTable.guessDelimiter(in: "\"x;y\",z\n\"1;2\",3\n") == .comma, "delimiters inside quotes don't count")
        #expect(CSVTable.guessDelimiter(in: "one\ncolumn\n") == .comma)
    }

    @Test func aHeaderIsTextOverNumbers() {
        #expect(table("name,price\nTea,3.50\nCake,4\n").guessHeader())
        #expect(table("name;price\nTea;3,50\n", .semicolon).guessHeader(locale: Locale(identifier: "de_DE")))
        #expect(!table("1,2\n3,4\n").guessHeader(), "numbers in the first row")
        #expect(!table("a,b\nc,d\n").guessHeader(), "all text")
        #expect(table("only,row\n").guessHeader(), "a one-row file")
    }
}

@Suite struct CSVEditing {
    @Test func unchangedRowsAreWrittenAsRead() {
        var t = table("a , b,\"c\"\n1,2,3\nx,y,z\n")
        t.setCell("9", row: 1, column: 0)
        #expect(t.serialized(lineEnding: "\n") == "a , b,\"c\"\n9,2,3\nx,y,z\n")
    }

    @Test func fieldsAreQuotedWhenTheyNeedIt() {
        var t = table("a,b\n")
        t.setCell("x,y", row: 0, column: 0)
        t.setCell("say \"hi\"", row: 0, column: 1)
        #expect(t.serialized(lineEnding: "\n") == "\"x,y\",\"say \"\"hi\"\"\"\n")
    }

    @Test func aQuotedFieldStaysQuoted() {
        var t = table("\"a\",b\n")
        t.setCell("z", row: 0, column: 1)
        #expect(t.serialized(lineEnding: "\n") == "\"a\",z\n")
    }

    @Test func theFileLineEndingAndFinalBreakAreKept() {
        var t = table("a,b\r\n1,2")
        t.setCell("3", row: 1, column: 1)
        #expect(t.serialized(lineEnding: "\r\n") == "a,b\r\n1,3")
    }

    @Test func settingACellPastTheRowEndPadsIt() {
        var t = table("a\n")
        t.setCell("c", row: 0, column: 2)
        #expect(t.serialized(lineEnding: "\n") == "a,,c\n")
    }

    @Test func rowsComeAndGoAndComeBackAsTheyWere() {
        var t = table("a,b\n1,2\nx,y\n")
        let removed = t.removeRows(at: IndexSet([0, 2]))
        #expect(cells(t) == [["1", "2"]])
        t.insertRows(removed, at: IndexSet([0, 2]))
        #expect(t.serialized(lineEnding: "\n") == "a,b\n1,2\nx,y\n")
        t.insertRows([CSVTable.emptyRow], at: IndexSet([1]))
        #expect(cells(t)[1] == ["", ""] && t.rowCount == 4)
    }

    @Test func columnsComeAndGo() {
        var t = table("a,b,c\n1,2,3\n")
        t.insertColumn(at: 1)
        #expect(cells(t) == [["a", "", "b", "c"], ["1", "", "2", "3"]])
        t.removeColumns(at: [0])
        #expect(t.serialized(lineEnding: "\n") == ",b,c\n,2,3\n")
        t.moveColumn(from: 2, to: 0)
        #expect(cells(t)[0] == ["c", "", "b"])
    }

    @Test func rowsMove() {
        var t = table("a\nb\nc\nd\n")
        t.moveRows(from: IndexSet([0, 1]), to: 3)
        #expect(cells(t).map(\.[0]) == ["c", "a", "b", "d"])
    }

    @Test func allRowsSwapForUndo() {
        var t = table("a,b\n1,2\n")
        let before = t.rows
        t.removeColumns(at: [0])
        t.rows = before
        #expect(t.serialized(lineEnding: "\n") == "a,b\n1,2\n")
    }
}

@Suite struct CSVReviewFixes {
    @Test func scatteredRowsComeAndGoInOneStep() {
        var t = CSVTable(text: (0..<2000).map { "\($0)" }.joined(separator: "\n") + "\n", delimiter: .comma)
        let picked = IndexSet((0..<2000).filter { $0 % 2 == 0 })
        let removed = t.removeRows(at: picked)
        #expect(t.rowCount == 1000 && t.cell(row: 0, column: 0) == "1")
        t.insertRows(removed, at: picked)
        #expect((0..<2000).allSatisfy { t.cell(row: $0, column: 0) == "\($0)" })
    }

    @Test func notANumberIsntANumber() {
        #expect(CSVTable.number("nan", locale: Locale(identifier: "en_US")) == nil)
        #expect(CSVTable.number("inf", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test func localeNumbersParseAndTextWithDigitsDoesnt() {
        #expect(CSVTable.number("1.234,5", locale: Locale(identifier: "de_DE")) == 1234.5)
        #expect(CSVTable.number("1,234,567", locale: Locale(identifier: "en_US")) == 1_234_567)
        #expect(CSVTable.number("1e3", locale: Locale(identifier: "en_US")) == 1000)
        #expect(CSVTable.number("person 12", locale: Locale(identifier: "en_US")) == nil)
        #expect(CSVTable.number("12 kg", locale: Locale(identifier: "en_US")) == nil)
    }

    @Test func aSemicolonTieWithCommasGoesToSemicolons() {
        #expect(CSVTable.guessDelimiter(in: "Tea;3,50\nCake;4,20\n") == .semicolon)
    }
}
