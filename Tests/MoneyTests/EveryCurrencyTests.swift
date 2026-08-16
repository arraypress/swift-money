//
//  EveryCurrencyTests.swift
//  Money
//
//  Created by David Sherlock on 2026.
//
//  The other test files pick a currency to make a point with: the pound for
//  the ordinary case, the yen for no decimals, the dinar for three. This one
//  makes no choice. It walks every code in the table — all of them, on every
//  run — and asserts the things that have to be true of all of them.
//
//  The reason is that the bugs in money code are not in the currency somebody
//  was thinking about while writing it. They are in the fourteenth one down
//  the list, where a rounding step assumed two places, or a string got padded
//  to the wrong width, and the amount came out ten times too small in a
//  country nobody on the project has been to.
//

import Foundation
import XCTest
@testable import Money

final class EveryCurrencyTests: XCTestCase {

    /// Every code the table knows — around 180 of them.
    private let all = Currency.known

    /// A label that says which currency failed, since the assertion itself
    /// looks the same for all of them.
    private func label(_ currency: Currency) -> String {
        "\(currency.code) (\(currency.decimals) places)"
    }

    // MARK: The shape of the table

    func testThereIsATableAndItIsNotEmpty() {
        XCTAssertGreaterThan(all.count, 150, "the table has lost most of its rows")

        for currency in all {
            XCTAssertEqual(currency.code.count, 3, label(currency))
            XCTAssertEqual(currency.code, currency.code.uppercased(), label(currency))
            XCTAssertTrue(currency.isKnown, label(currency))
        }
    }

    func testEveryCurrencyHasAPlausibleNumberOfPlaces() {
        // ISO 4217 has never issued anything outside this range, and the
        // arithmetic below assumes it: five places would overflow the scaling
        // on large amounts long before Int did.
        for currency in all {
            XCTAssertTrue((0...4).contains(currency.decimals), label(currency))
            XCTAssertEqual(
                currency.unitsPerMajor,
                Int(pow(10.0, Double(currency.decimals))),
                label(currency)
            )
        }
    }

    func testNoCodeAppearsTwiceWithDifferentPlaces() {
        // A dictionary cannot hold a duplicate key, so this is really a check
        // on the source lists: a code in both the "three places" list and the
        // ordinary one would silently take whichever ran last.
        XCTAssertEqual(Set(all.map(\.code)).count, all.count)
    }

    // MARK: Writing an amount out

    func testTheWrittenFormAlwaysHasExactlyTheRightNumberOfDecimals() {
        for currency in all {
            for units in [0, 1, 5, 99, 100, 101, 999, 1_000, 12_345, 999_999_999] {
                let written = Money(units: units, in: currency).decimalString

                guard currency.decimals > 0 else {
                    XCTAssertFalse(written.contains("."),
                                   "\(label(currency)) wrote a decimal point: \(written)")
                    continue
                }

                let parts = written.split(separator: ".")
                XCTAssertEqual(parts.count, 2, "\(label(currency)): \(written)")
                XCTAssertEqual(parts.last?.count, currency.decimals,
                               "\(label(currency)): \(written)")
            }
        }
    }

    func testTheSmallestUnitIsNotWrittenAsAWholeOne() {
        // The padding bug: one minor unit in a two-place currency is 0.01,
        // and an unpadded remainder writes it as 0.1 — ten times the amount.
        let expected = [0: "1", 1: "0.1", 2: "0.01", 3: "0.001", 4: "0.0001"]

        for currency in all {
            XCTAssertEqual(
                Money(units: 1, in: currency).decimalString,
                expected[currency.decimals],
                label(currency)
            )
        }
    }

    func testANegativeAmountKeepsItsSignAndItsPadding() {
        // A credit note is an invoice with the sign flipped, so this is not a
        // hypothetical shape. The failure to watch for is the minus landing
        // after the point, or the padding being computed from the signed
        // remainder and coming out short.
        for currency in all {
            let written = Money(units: -1, in: currency).decimalString

            XCTAssertTrue(written.hasPrefix("-"), "\(label(currency)): \(written)")
            XCTAssertEqual(written.dropFirst().filter { $0 == "-" }.count, 0,
                           "\(label(currency)) wrote a second minus: \(written)")
            XCTAssertEqual(String(written.dropFirst()),
                           Money(units: 1, in: currency).decimalString,
                           label(currency))
        }
    }

    func testNothingIsWrittenAsNothingRatherThanAsMinusNothing() {
        for currency in all {
            XCTAssertEqual(Money.zero(currency).decimalString,
                           currency.decimals > 0
                               ? "0." + String(repeating: "0", count: currency.decimals)
                               : "0",
                           label(currency))
        }
    }

    // MARK: Reading an amount back

    func testWhatIsWrittenCanBeReadBack() {
        // The round trip that matters: whatever a document prints, parsing it
        // has to give back the same integer. If this holds for every currency
        // then no amount can change on the way through a file.
        for currency in all {
            for units in [0, 1, 7, 50, 99, 100, 4_999, 100_000, 87_654_321] {
                let money = Money(units: units, in: currency)
                XCTAssertEqual(Money(money.decimalString, in: currency), money, label(currency))
            }
        }
    }

    func testAFinerAmountThanTheCurrencyHasIsRefused() {
        // Half a yen is not an amount anybody can pay, and a tenth of a penny
        // is not one anybody can invoice. Refusing beats rounding silently:
        // the caller who meant it can say so through the Decimal initialiser.
        for currency in all {
            let tooFine = "1." + String(repeating: "0", count: currency.decimals) + "5"
            XCTAssertNil(Money(tooFine, in: currency),
                         "\(label(currency)) accepted \(tooFine)")
        }
    }

    func testTheDecimalRoundTripIsExact() {
        // Decimal is base ten, so this should be lossless in both directions
        // for every scale in the table — including the four-place ones, where
        // a binary float would already have drifted.
        for currency in all {
            for units in [1, 99, 12_345, 999_999, 123_456_789] {
                let money = Money(units: units, in: currency)
                XCTAssertEqual(Money(money.decimal, in: currency), money, label(currency))
            }
        }
    }

    // MARK: Arithmetic, in every currency

    func testAdditionAndSubtractionInvert() {
        for currency in all {
            let a = Money(units: 123_456, in: currency)
            let b = Money(units: 7_899, in: currency)

            XCTAssertEqual((a + b) - b, a, label(currency))
            XCTAssertEqual(a - a, Money.zero(currency), label(currency))
            XCTAssertEqual(-(-a), a, label(currency))
        }
    }

    func testALongColumnOfFiguresAddsUp() {
        // A thousand lines is where a float would already be visibly wrong.
        for currency in all {
            let lines = (1...1_000).map { Money(units: $0, in: currency) }
            XCTAssertEqual(Money.total(lines)?.units, 500_500, label(currency))
        }
    }

    func testDividingAnAmountLosesNothing() {
        // The classic: a pound in three. Whatever the parts come to, they
        // have to add back up to exactly what went in, in every currency and
        // every division — otherwise the difference is money that stopped
        // existing.
        for currency in all {
            for units in [1, 2, 100, 101, 1_000, 999_983] {
                for parts in [1, 2, 3, 7, 12, 100] {
                    let money = Money(units: units, in: currency)
                    let split = money.allocate(parts)

                    XCTAssertEqual(split.count, parts, label(currency))
                    XCTAssertEqual(Money.total(split), money,
                                   "\(label(currency)): \(units) into \(parts)")

                    // And no part is more than one unit off any other, so the
                    // remainder is spread rather than dumped on one line.
                    let spread = (split.map(\.units).max() ?? 0) - (split.map(\.units).min() ?? 0)
                    XCTAssertLessThanOrEqual(spread, 1, label(currency))
                }
            }
        }
    }

    func testDividingInProportionLosesNothing() {
        for currency in all {
            let money = Money(units: 100_000, in: currency)

            for ratios in [[1, 1], [1, 2, 3], [7, 11, 13, 17], [1, 0, 1], [999, 1]] {
                let split = money.allocate(ratios: ratios)
                XCTAssertEqual(Money.total(split), money,
                               "\(label(currency)): \(ratios)")
            }
        }
    }

    func testTaxAlwaysAddsBackUp() {
        // The invoice invariant, in every currency and at every rate anybody
        // charges: what is printed as net, plus what is printed as tax, is
        // what is printed as the total. A rounding step that disagreed with
        // the printing would show up here as an invoice that does not add up.
        for currency in all {
            for rate in [Decimal(0), 5, 7.7, 19, 20, 21, 23, 25, 27] {
                let net = Money(units: 749_00, in: currency)
                let tax = net.percentage(rate)
                let gross = net.adding(percent: rate)

                XCTAssertEqual(net + tax, gross, "\(label(currency)) at \(rate)%")
            }
        }
    }

    func testTaxTakenBackOutOfAGrossAmountIsWithinAUnit() {
        // Working backwards cannot always be exact — some gross amounts are
        // not reachable from any net one — but it has to land on the unit
        // next to it rather than somewhere else entirely.
        for currency in all {
            for rate in [Decimal(5), 19, 20, 23] {
                let gross = Money(units: 1_234_56, in: currency)
                let tax = gross.taxIncluded(at: rate)
                let net = gross - tax

                XCTAssertEqual(net.adding(percent: rate).units, gross.units, accuracy: 1,
                               "\(label(currency)) at \(rate)%")
            }
        }
    }

    // MARK: Printing for a reader

    func testEveryCurrencyPrintsSomethingAReaderCanUse() {
        for currency in all {
            let money = Money(units: 123_456, in: currency)

            for locale in [Locale(identifier: "en_GB"), Locale(identifier: "de_DE"),
                           Locale(identifier: "ja_JP"), Locale(identifier: "ar_EG")] {
                let printed = money.formatted(in: locale)

                XCTAssertFalse(printed.isEmpty, label(currency))
                XCTAssertTrue(printed.contains(where: \.isNumber),
                              "\(label(currency)) in \(locale.identifier): \(printed)")
            }
        }
    }

    func testTheUnambiguousFormAlwaysCarriesTheCode() {
        // What a document that crosses a border prints, because "$" is at
        // least eight currencies and "£" is four.
        for currency in all {
            XCTAssertTrue(
                Money(units: 1_000, in: currency)
                    .formattedWithCode(in: Locale(identifier: "en_GB"))
                    .contains(currency.code),
                label(currency)
            )
        }
    }

    // MARK: Surviving a file

    func testEveryCurrencySurvivesJSON() {
        for currency in all {
            let money = Money(units: -98_765, in: currency)
            do {
                let data = try JSONEncoder().encode(money)
                XCTAssertEqual(try JSONDecoder().decode(Money.self, from: data), money,
                               label(currency))
            } catch {
                XCTFail("\(label(currency)): \(error)")
            }
        }
    }

    // MARK: The edges of the type

    func testLargeAmountsDoNotOverflowInAnyCurrency() {
        // The four-place currencies are the tight ones: an amount is held in
        // minor units, so the same national figure is ten thousand times the
        // integer it would be in a currency with none. This is a trillion of
        // whatever it is — comfortably past any real invoice, and still far
        // inside Int64 even at four places.
        for currency in all {
            let large = Money(units: 1_000_000_000_000 * currency.unitsPerMajor, in: currency)

            XCTAssertEqual(Money(large.decimalString, in: currency), large, label(currency))
            XCTAssertEqual((large + large) - large, large, label(currency))
            XCTAssertEqual(Money.total(large.allocate(7)), large, label(currency))
            XCTAssertEqual(large.percentage(20).units, large.units / 5, label(currency))
        }
    }

    func testAnAmountBeyondTheTypeIsRefusedRatherThanWrapped() {
        // Not a real amount in any currency, but it is a string somebody can
        // put in a file, and wrapping silently into a negative would be the
        // worst possible answer.
        for currency in all {
            XCTAssertNil(Money(String(repeating: "9", count: 30), in: currency), label(currency))
        }
    }

    func testAnUnknownCodeBehavesLikeAnOrdinaryOne() {
        // A code the table has not caught up with should still work, at the
        // two places that almost everything uses, rather than crashing or
        // producing an amount with no decimals at all.
        let future = Currency("ZZZ")

        XCTAssertFalse(future.isKnown)
        XCTAssertEqual(future.decimals, 2)
        XCTAssertEqual(Money("12.34", in: future)?.decimalString, "12.34")
        XCTAssertEqual(Money.total(Money(units: 100, in: future).allocate(3))?.units, 100)
    }
}
