//
//  CurrencyTests.swift
//  Money
//
//  Created by David Sherlock on 2026.
//

import Foundation
import XCTest
@testable import Money

final class CurrencyTests: XCTestCase {

    // MARK: The table, against the system

    /// Where ICU and ISO 4217 genuinely disagree, and why.
    ///
    /// ICU tracks what people *do*: nobody quotes fractions of a forint, a
    /// rupiah or a dinar in Baghdad, so it reports no decimals. ISO 4217
    /// records what the currency *is*, and that is what the e-invoicing
    /// schemas and the banks reference. This library follows the standard
    /// for arithmetic, because an invoice is a record rather than a
    /// shopfront — and lists the divergence rather than pretending it away.
    private static let usageDiffersFromStandard: Set<String> = [
        "AFN", "ALL", "COP", "HUF", "IDR", "IQD", "IRR", "KPW", "LAK",
        "LBP", "MGA", "MMK", "PKR", "RSD", "SOS", "SYP", "YER",
    ]

    func testTheTableAgreesWithFoundationExceptWhereItMeansTo() throws {
        // The table is pinned so a document renders identically on every
        // machine, and ICU ships with the operating system — so the two can
        // drift. This is how we find out: on a run, not in somebody's
        // accounts.
        var surprises: [String] = []

        for currency in Currency.known where !Self.usageDiffersFromStandard.contains(currency.code) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = currency.code

            guard formatter.currencySymbol != nil, formatter.currencyCode == currency.code
            else { continue }

            if formatter.maximumFractionDigits != currency.decimals {
                surprises.append("\(currency.code): table says \(currency.decimals), "
                                 + "the system says \(formatter.maximumFractionDigits)")
            }
        }

        XCTAssertEqual(surprises, [], "ICU and the table have drifted somewhere new")
    }

    func testTheKnownDivergencesAreStillDivergent() {
        // If ICU comes round to the standard, the list above is stale and
        // should shrink — which is worth being told about.
        var agreed: [String] = []

        for code in Self.usageDiffersFromStandard {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = code

            if formatter.maximumFractionDigits == Currency(code).decimals {
                agreed.append(code)
            }
        }

        XCTAssertEqual(agreed, [], "these no longer differ; the list can lose them")
    }

    func testTheStandardIsWhatArithmeticFollows() {
        // A forint has two decimal places in ISO 4217 even though nobody
        // quotes fillér, and an invoice is a record rather than a shopfront.
        XCTAssertEqual(Currency("HUF").decimals, 2)
        XCTAssertEqual(Currency("IQD").decimals, 3, "the Iraqi dinar has fils, whatever ICU says")
        XCTAssertEqual(Money("1234.56", in: Currency("HUF"))?.units, 123_456)
    }

    func testTheSystemKnowsCurrenciesTheTableDoesNot() {
        // Expected, and not a fault: the table carries what this library
        // needs to be exact about, not every code ever minted.
        XCTAssertLessThan(Currency.known.count, Locale.Currency.isoCurrencies.count)
    }

    // MARK: Places

    func testTheCurrenciesThatAreNotTwo() {
        XCTAssertEqual(Currency("JPY").decimals, 0)
        XCTAssertEqual(Currency("KRW").decimals, 0)
        XCTAssertEqual(Currency("XOF").decimals, 0)
        XCTAssertEqual(Currency("KWD").decimals, 3)
        XCTAssertEqual(Currency("BHD").decimals, 3)
        XCTAssertEqual(Currency("CLF").decimals, 4)
    }

    func testEverythingElseIsTwo() {
        for code in ["GBP", "EUR", "USD", "CHF", "AUD", "INR", "BRL"] {
            XCTAssertEqual(Currency(code).decimals, 2, code)
        }
    }

    func testAnUnknownCodeIsAllowedAndAssumedOrdinary() {
        // A private settlement currency, or one minted after this was
        // written, is not a reason to refuse to add up.
        let invented = Currency("ZZZ")
        XCTAssertFalse(invented.isKnown)
        XCTAssertEqual(invented.decimals, 2)
        XCTAssertEqual(Money("12.34", in: invented)?.units, 1234)
    }

    func testTheCodeIsUpperCased() {
        XCTAssertEqual(Currency("gbp").code, "GBP")
        XCTAssertEqual(Currency("gbp"), Currency("GBP"))
    }

    func testUnitsPerMajor() {
        XCTAssertEqual(Currency("JPY").unitsPerMajor, 1)
        XCTAssertEqual(Currency("GBP").unitsPerMajor, 100)
        XCTAssertEqual(Currency("KWD").unitsPerMajor, 1000)
        XCTAssertEqual(Currency("CLF").unitsPerMajor, 10_000)
    }

    // MARK: Printing

    func testItPrintsAsSomebodyInThatPlaceWouldRead() throws {
        let british = Locale(identifier: "en_GB")
        XCTAssertEqual(Money("1234.56", in: .gbp)?.formatted(in: british), "£1,234.56")

        // Read in Britain, the yen is disambiguated as JP¥ — which is ICU
        // being helpful rather than wrong, and not something to pin.
        let yen = try XCTUnwrap(Money("1000", in: .jpy)?.formatted(in: british))
        XCTAssertTrue(yen.contains("1,000"), yen)
        XCTAssertTrue(yen.contains("¥"), yen)
    }

    func testTheYenIsPrintedWithoutDecimals() throws {
        let printed = try XCTUnwrap(Money("1000", in: .jpy)?.formatted(in: Locale(identifier: "en_US")))
        XCTAssertFalse(printed.contains(".00"), printed)
    }

    func testACodeRatherThanASymbolForDocumentsThatCrossABorder() throws {
        // "$1,234.56" is four currencies, and a customer in Toronto reading
        // an invoice from Sydney should not have to guess which.
        let printed = try XCTUnwrap(
            Money("1234.56", in: .usd)?.formattedWithCode(in: Locale(identifier: "en_GB"))
        )
        XCTAssertTrue(printed.contains("USD"), printed)
        XCTAssertTrue(printed.contains("1,234.56"), printed)
    }

    func testTheUnambiguousForm() {
        XCTAssertEqual(Money("1234.56", in: .gbp)?.description, "GBP 1234.56")
    }

    func testTheCodeFormEndsCleanlyWhereTheSymbolTrails() throws {
        // A German reader's pattern puts the currency after the number, and
        // the space this appends to separate a leading code became a stray
        // trailing one there: "1.234,56 EUR ". The code must end the string.
        let german = try XCTUnwrap(
            Money("1234.56", in: .eur)?.formattedWithCode(in: Locale(identifier: "de_DE"))
        )
        XCTAssertTrue(german.hasSuffix("EUR"), "[\(german)]")
        XCTAssertFalse(german.last?.isWhitespace ?? false, "[\(german)]")

        // And where the code leads, the separating space survives the trim.
        let british = try XCTUnwrap(
            Money("1234.56", in: .gbp)?.formattedWithCode(in: Locale(identifier: "en_GB"))
        )
        XCTAssertTrue(british.hasPrefix("GBP 1,234.56"), "[\(british)]")
    }

    // MARK: Codable

    func testMoneySurvivesJSON() throws {
        let amount = Money("1234.56", in: .gbp)!
        let decoded = try JSONDecoder().decode(Money.self, from: try JSONEncoder().encode(amount))

        XCTAssertEqual(decoded, amount)
        XCTAssertEqual(decoded.decimalString, "1234.56")
    }
}
