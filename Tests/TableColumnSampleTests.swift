import Foundation
@testable import PeekerTable
import Testing

private func samples(_ text: String, header: Bool = true) -> [ColumnSample] {
    let table = CSVTable(text: text, delimiter: .comma)
    return ColumnSample.sample(table, hasHeader: header, rows: (header ? 1 : 0)..<table.rowCount)
}

@Suite struct ColumnSampling {
    @Test func keepsTheTitleAndTheLongestCellsLongestFirst() {
        let s = samples("note\na\nlongest one\nbb\nmid text\nccc\n")
        #expect(s[0].title == "note")
        #expect(s[0].longest == ["longest one", "mid text", "ccc"])
    }

    @Test func aColumnOfNumbersIsNumericAndTextIsNot() {
        let s = samples("name,price\nTea,2.50\nCake,3.50\nBread,12\n")
        #expect(!s[0].isNumeric && s[1].isNumeric)
    }

    @Test func aMixedColumnIsNotNumeric() {
        #expect(!samples("v\n1\n2\nn/a\nunknown\n")[0].isNumeric)
    }

    @Test func emptyCellsDontCountAgainstNumbers() {
        #expect(samples("v\n1\n\n\n2\n")[0].isNumeric)
    }

    @Test func theHeaderIsNotCountedAsANumber() {
        // Without a header row, "price" is a text cell in the column.
        #expect(!samples("price\n2\n3\n", header: false)[0].isNumeric)
        #expect(samples("price\n2\n3\n")[0].isNumeric)
    }

    @Test func raggedRowsAndLineBreaks() {
        let s = samples("a,b,c\n1\n2,\"two\nlines\",x\n")
        #expect(s.count == 3)
        #expect(s[1].longest == ["two lines"] && s[2].longest == ["x"])
    }

    @Test func onlyTheFirstRowsAreRead() {
        let rows = (0..<1_500).map { $0 < 1_000 ? "1" : "a much longer cell past the sample" }
        #expect(samples("v\n" + rows.joined(separator: "\n"))[0].longest == ["1", "1", "1"])
    }
}
