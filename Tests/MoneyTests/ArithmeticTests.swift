//
//  ArithmeticTests.swift
//  Money
//
//  Created by David Sherlock on 2026.
//

import Foundation
import XCTest
@testable import Money

final class ArithmeticTests: XCTestCase {

    private func gbp(_ text: String) -> Money { Money(text, in: .gbp)! }

    // MARK: Adding up

    func testAddingAndSubtracting() {
        XCTAssertEqual((gbp("12.34") + gbp("0.66")).decimalString, "13.00")
        XCTAssertEqual((gbp("12.34") - gbp("12.35")).decimalString, "-0.01")
        XCTAssertEqual((-gbp("12.34")).decimalString, "-12.34")
        XCTAssertEqual((gbp("1.11") * 3).decimalString, "3.33")
    }

    func testAThousandLinesStillAddUp() {
        // The failure this type exists to prevent: a thousand additions of
        // ten pence, which in binary floating point is not a hundred pounds.
        let total = Money.total(Array(repeating: gbp("0.10"), count: 1000))
        XCTAssertEqual(total?.decimalString, "100.00")
    }

    func testTotallingNothing() {
        // There is no zero without a currency to be zero in.
        XCTAssertNil(Money.total([Money]()))
        XCTAssertEqual(Money.total([gbp("1.00")])?.decimalString, "1.00")
    }

    func testComparing() {
        XCTAssertTrue(gbp("1.00") < gbp("1.01"))
        XCTAssertEqual(gbp("1.00"), Money(units: 100, in: .gbp))
        XCTAssertEqual([gbp("3.00"), gbp("1.00"), gbp("2.00")].max(), gbp("3.00"))
    }

    // MARK: Percentages

    func testAPercentageIsExactUntilTheLastStep() {
        // 20% of £1,234.56 is 24,691.2 pence; only the final rounding is a
        // decision.
        XCTAssertEqual(gbp("1234.56").percentage(20).decimalString, "246.91")
        XCTAssertEqual(gbp("1234.56").percentage(20, rounding: .down).decimalString, "246.91")
        XCTAssertEqual(gbp("100.00").percentage(19).decimalString, "19.00")
    }

    func testMakingANetFigureGross() {
        XCTAssertEqual(gbp("100.00").adding(percent: 20).decimalString, "120.00")
        XCTAssertEqual(gbp("1234.56").adding(percent: 20).decimalString, "1481.47")
    }

    func testTheTaxInsideAnAmount() {
        // £120 including 20% holds £20, not £24 — the commonest mistake in a
        // spreadsheet full of invoices.
        XCTAssertEqual(gbp("120.00").taxIncluded(at: 20).decimalString, "20.00")
        XCTAssertEqual(gbp("100.00").taxIncluded(at: 20).decimalString, "16.67")
        XCTAssertNotEqual(gbp("120.00").taxIncluded(at: 20).decimalString, "24.00")
    }

    func testTaxOnNothingIsNothing() {
        XCTAssertEqual(gbp("0.00").taxIncluded(at: 20).decimalString, "0.00")
        XCTAssertEqual(gbp("100.00").taxIncluded(at: 0).decimalString, "0.00")
    }

    // MARK: Dividing

    func testAPoundInThreeLosesNothing() {
        // 34p, 33p, 33p — not three lots of 33.3p, and not three lots of 33p
        // with a penny left in the machine.
        let shares = gbp("1.00").allocate(3)

        XCTAssertEqual(shares.map(\.decimalString), ["0.34", "0.33", "0.33"])
        XCTAssertEqual(Money.total(shares), gbp("1.00"))
    }

    func testEveryDivisionAddsBackUp() {
        for parts in 1...12 {
            for pence in [1, 7, 100, 1234, 99999] {
                let amount = Money(units: pence, in: .gbp)
                let shares = amount.allocate(parts)

                XCTAssertEqual(shares.count, parts)
                XCTAssertEqual(Money.total(shares), amount, "\(pence)p in \(parts)")
            }
        }
    }

    func testANegativeAmountDividesToo() {
        // A refund split three ways is still a refund.
        let shares = gbp("-1.00").allocate(3)
        XCTAssertEqual(shares.map(\.decimalString), ["-0.34", "-0.33", "-0.33"])
        XCTAssertEqual(Money.total(shares), gbp("-1.00"))
    }

    func testDividingByNothing() {
        XCTAssertTrue(gbp("1.00").allocate(0).isEmpty)
        XCTAssertTrue(gbp("1.00").allocate(-3).isEmpty)
    }

    func testDividingInProportion() {
        // A discount spread across three lines by their value.
        let shares = gbp("10.00").allocate(ratios: [1, 1, 2])

        XCTAssertEqual(Money.total(shares), gbp("10.00"))
        XCTAssertEqual(shares[2], shares[0] + shares[1])
    }

    func testProportionsThatDoNotDivideEvenlyStillAddUp() {
        for ratios in [[1, 1, 1], [1, 2, 3], [7, 11, 13], [1, 0, 1], [5]] {
            let shares = gbp("100.00").allocate(ratios: ratios)
            XCTAssertEqual(Money.total(shares), gbp("100.00"), "\(ratios)")
            XCTAssertEqual(shares.count, ratios.count)
        }
    }

    func testMeaninglessProportions() {
        XCTAssertTrue(gbp("1.00").allocate(ratios: []).isEmpty)
        XCTAssertTrue(gbp("1.00").allocate(ratios: [0, 0]).isEmpty)
    }

    func testTheYenDividesInWholeYen() {
        let shares = Money("1000", in: .jpy)!.allocate(3)
        XCTAssertEqual(shares.map(\.decimalString), ["334", "333", "333"])
        XCTAssertEqual(Money.total(shares)?.decimalString, "1000")
    }
}
