//
//  EdgeTests.swift
//  Money
//
//  Created by David Sherlock on 2026.
//
//  The inputs nobody means to give it.
//
//  Every one of these was found by handing the type something absurd and
//  looking at what came back, and four of them came back wrong: a number too
//  large wrapped into a smaller one, a not-a-number produced a plausible
//  amount, a proportional division crashed on a large sum, and an amount in
//  an unrecognised currency printed with the symbol of wherever the reader
//  was sitting. All four are the same failure — answering confidently instead
//  of refusing — and all four are here so they stay fixed.
//

import Foundation
import XCTest
@testable import Money

final class EdgeTests: XCTestCase {

    // MARK: Numbers too big to be amounts

    func testANumberTooLargeToHoldIsRefusedRatherThanWrapped() {
        // 10^23 pounds. `intValue` used to hand back the low bits of this as
        // though they were the number, which made it £15,908,979,783,594,146
        // — a different amount, in range, with nothing to show it had
        // happened.
        let absurd = Decimal(string: "99999999999999999999999")!

        XCTAssertNil(Money(exactly: absurd, in: .gbp))
        XCTAssertNil(Money(exactly: -absurd, in: .gbp))
    }

    func testTheLimitIsWhereTheTypeActuallyEnds() {
        // Exactly what fits is kept; one unit past it is refused. The bound
        // is checked in Decimal, which is exact at this size, rather than by
        // converting first and looking at the result.
        let largest = Decimal(Int.max) / Decimal(100)

        XCTAssertEqual(Money(exactly: largest, in: .gbp)?.units, Int.max)
        XCTAssertNil(Money(exactly: largest + Decimal(string: "0.01")!, in: .gbp))

        let smallest = Decimal(Int.min) / Decimal(100)
        XCTAssertEqual(Money(exactly: smallest, in: .gbp)?.units, Int.min)
        XCTAssertNil(Money(exactly: smallest - Decimal(string: "0.01")!, in: .gbp))
    }

    func testTheLimitIsLowerInACurrencyWithMoreDecimals() {
        // The same national figure is ten thousand times the integer in a
        // four-place currency, so the ceiling is four orders of magnitude
        // nearer — which is exactly the case somebody would not think to try.
        let large = Decimal(string: "10000000000000000")!  // 10^16

        XCTAssertNotNil(Money(exactly: large, in: .gbp))
        XCTAssertNil(Money(exactly: large, in: Currency("CLF")))
    }

    func testSomethingThatIsNotANumberIsRefused() {
        // A NaN Decimal used to produce £43,503,537.37 — an amount that looks
        // entirely real on an invoice.
        XCTAssertNil(Money(exactly: Decimal.nan, in: .gbp))
        XCTAssertNil(Money(exactly: Decimal.quietNaN, in: .gbp))
    }

    func testAnAmountFromOrdinaryArithmeticStillNeedsNoUnwrapping() {
        // The refusal is on the `exactly` initialiser so that the everyday
        // one stays an expression rather than an optional. What it does with
        // something unholdable is stop, loudly, which is not something a test
        // can call — but this is the case it is there to keep easy.
        XCTAssertEqual(Money(Decimal(string: "1234.56")!, in: .gbp).units, 123_456)
        XCTAssertEqual(Money(Decimal(string: "-0.005")!, in: .gbp).units, -1)
    }

    // MARK: Dividing a very large amount

    func testAProportionalDivisionOfALargeAmountDoesNotCrash() {
        // `units * ratio / total` in Int overflowed and trapped: a trillion
        // of a four-place currency is 10^16 minor units, and a ratio in the
        // thousands took the product past Int64 on the way to a division that
        // lands nowhere near it.
        let large = Money(units: 10_000_000_000_000_000, in: Currency("CLF"))
        let shares = large.allocate(ratios: [1_000, 2_000])

        XCTAssertEqual(shares.count, 2)
        XCTAssertEqual(Money.total(shares), large, "money went missing in the division")
    }

    func testTheLargestAmountThereIsCanStillBeDivided() {
        let most = Money(units: Int.max, in: .gbp)

        for ratios in [[1, 1], [1, 2, 3], [1_000_000, 7]] {
            XCTAssertEqual(Money.total(most.allocate(ratios: ratios)), most, "\(ratios)")
        }
        XCTAssertEqual(Money.total(most.allocate(7)), most)
    }

    func testANegativeAmountDividesInProportionToo() {
        // A credit note spread over the lines it credits.
        let refund = Money(units: -100_00, in: .gbp)
        let shares = refund.allocate(ratios: [1, 1, 1])

        XCTAssertEqual(Money.total(shares), refund)
        XCTAssertTrue(shares.allSatisfy(\.isNegative))
    }

    func testProportionsThatAreNotProportionsAreRefused() {
        let pound = Money(units: 100, in: .gbp)

        XCTAssertTrue(pound.allocate(ratios: []).isEmpty)
        XCTAssertTrue(pound.allocate(ratios: [0, 0]).isEmpty)
        XCTAssertTrue(pound.allocate(ratios: [-1, -2]).isEmpty, "the total is not positive")
    }

    // MARK: Currencies that are not currencies

    func testAnAmountInNoCurrencyDoesNotPrintAsTheReadersOwn() {
        // Foundation, asked for the symbol of an empty code, returns the one
        // for wherever the reader is. So an amount with no currency printed
        // as pounds in London and as dollars in New York — the two worst
        // possible answers, because both look correct.
        XCTAssertEqual(Currency("").symbol, "")
        XCTAssertEqual(Currency("gb").symbol, "GB")
        XCTAssertEqual(Currency("POUNDS").symbol, "POUNDS")
        XCTAssertEqual(Currency("12").symbol, "12")
    }

    func testACodeTheSystemDoesNotKnowGetsItselfBack() {
        XCTAssertEqual(Currency("ZZZ").symbol, "ZZZ")
        XCTAssertFalse(Currency("ZZZ").isKnown)
    }

    func testTheOnesTheSystemDoesKnowAreStillAskedFor() {
        // The fallback must not have swallowed the real answers.
        XCTAssertEqual(Currency.gbp.symbol, "£")
        XCTAssertEqual(Currency.eur.symbol, "€")
    }

    // MARK: Text that is nearly a number

    func testAnAmountReadFromAFileKeepsItsLineEnding() {
        // `head -1 amount.txt` gives you "12.34\n". Refusing that is refusing
        // the ordinary way of getting a number into a program.
        XCTAssertEqual(Money("12.34\n", in: .gbp)?.units, 1_234)
        XCTAssertEqual(Money("  12.34  \r\n", in: .gbp)?.units, 1_234)
        XCTAssertEqual(Money("\t12.34", in: .gbp)?.units, 1_234)
    }

    func testWhatIsStillRefused() {
        // The parser is deliberately strict about anything that is a display
        // choice rather than a number: separators, symbols, exponents and
        // digits from other scripts all mean somebody is passing in something
        // that was formatted for a reader.
        for text in ["1,234.56", "£12.34", "12.34 GBP", "1e3", "0x10",
                     "١٢.٣٤", "twelve", "12.3.4", "--12", "", " ", "-", "."] {
            XCTAssertNil(Money(text, in: .gbp), "accepted '\(text)'")
        }
    }

    func testTheLooseButUnambiguousFormsAreAccepted() {
        // These are not how anybody writes an amount, but each has exactly
        // one reading, and refusing them would only send somebody looking for
        // a typo that is not there.
        XCTAssertEqual(Money("+12.34", in: .gbp)?.units, 1_234)
        XCTAssertEqual(Money("12.", in: .gbp)?.units, 1_200)
        XCTAssertEqual(Money(".34", in: .gbp)?.units, 34)
        XCTAssertEqual(Money("0012.34", in: .gbp)?.units, 1_234)
        XCTAssertEqual(Money("-0.00", in: .gbp)?.units, 0)
    }

    // MARK: Rates that are not rates

    func testATaxRateOfNothingChangesNothing() {
        let net = Money(units: 100_00, in: .gbp)

        XCTAssertEqual(net.percentage(0), Money.zero(.gbp))
        XCTAssertEqual(net.adding(percent: 0), net)
        XCTAssertEqual(net.taxIncluded(at: 0), Money.zero(.gbp))
    }

    func testARateThatWouldDivideByNothingGivesNothing() {
        // −100% inside an amount means the gross was zero, which says nothing
        // about the tax. Zero is the only answer that is not invented.
        XCTAssertEqual(Money(units: 100_00, in: .gbp).taxIncluded(at: -100), Money.zero(.gbp))
    }

    func testANegativeRate() {
        // A discount expressed as a rate. It should behave like the positive
        // case with the sign flipped, and still add back up.
        let net = Money(units: 100_00, in: .gbp)

        XCTAssertEqual(net.percentage(-20).decimalString, "-20.00")
        XCTAssertEqual(net + net.percentage(-20), net.adding(percent: -20))
    }

    // MARK: Amounts in two currencies

    func testTwoCurrenciesAreNotTheSameAmount() {
        // The one thing this type exists to make impossible. Adding pounds to
        // yen is not an arithmetic problem with a wrong answer, it is a
        // question with no answer — so `+`, `-`, `<` and anything built on
        // them stop rather than return. That stop cannot be written as an
        // assertion here, since it takes the process with it; what can be is
        // that the two are never quietly treated as equal.
        XCTAssertNotEqual(Money(units: 100, in: .gbp), Money(units: 100, in: .eur))
        XCTAssertNotEqual(Money(units: 100, in: .gbp).hashValue,
                          Money(units: 100, in: .eur).hashValue)
    }

    func testTotallingAnEmptySequenceHasNoCurrencyToGuess() {
        XCTAssertNil(Money.total([Money]()))
    }
}

// MARK: - The conveniences, and where they stop

final class ConvenienceTests: XCTestCase {

    func testAColumnOfFiguresAddsUpTheWayItReads() {
        let lines = [Money("149.00", in: .gbp)!, Money("420.00", in: .gbp)!,
                     Money("180.00", in: .gbp)!]

        XCTAssertEqual(lines.total?.decimalString, "749.00")
        XCTAssertEqual(lines.total(in: .gbp)?.decimalString, "749.00")
    }

    func testANothingColumnIsZeroWhenTheCurrencyIsStatedAndNothingWhenItIsNot() {
        XCTAssertNil([Money]().total)
        XCTAssertEqual([Money]().total(in: .gbp), Money.zero(.gbp))
    }

    func testAStrayCurrencyInTheColumnIsRefusedRatherThanFatal() {
        // The point of the stated form: figures assembled from a file get a
        // nil to handle, where the inferred form would stop the process.
        let mixed = [Money(units: 100, in: .gbp), Money(units: 100, in: .eur)]

        XCTAssertNil(mixed.total(in: .gbp))
        XCTAssertNil(mixed.total(in: .eur))
    }

    func testACurrencyCanBeWrittenAsALiteral() {
        let price = Money("12.34", in: "GBP")
        XCTAssertEqual(price?.currency, .gbp)

        let currency: Currency = "jpy"
        XCTAssertEqual(currency, .jpy, "a literal should be upper-cased like any other code")
    }
}
