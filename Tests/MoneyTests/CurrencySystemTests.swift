import XCTest
@testable import Money

/// What the system says about a currency, read rather than tabled.
final class CurrencySystemTests: XCTestCase {

    func testTheNarrowSymbolIsTheCurrencysOwnWhateverTheLocale() {
        /// A British Mac writes `US$`; the dollar's own sign is `$`
        XCTAssertEqual(Currency.usd.narrowSymbol, "$")
        XCTAssertEqual(Currency.gbp.narrowSymbol, "£")
        XCTAssertEqual(Currency.jpy.narrowSymbol, "¥")
        XCTAssertEqual(Currency("THB").narrowSymbol, "฿")
        XCTAssertEqual(Currency.eur.narrowSymbol, "€")
    }

    func testACurrencyWithNoSignReadsAsItsCode() {
        XCTAssertEqual(Currency.chf.narrowSymbol, "CHF")
        XCTAssertEqual(Currency("KWD").narrowSymbol, "KWD")
        XCTAssertEqual(Currency("BTC").narrowSymbol, "BTC", "not a currency the system knows, so nothing to strip")
    }

    func testTheNameComesInTheLanguageAsked() {
        XCTAssertEqual(Currency("THB").localizedName(in: Locale(identifier: "en_GB")), "Thai Baht")
        XCTAssertEqual(Currency.eur.localizedName(in: Locale(identifier: "de_DE")), "Euro")
        XCTAssertNil(Currency("ZZZ").localizedName(in: Locale(identifier: "en_US")))
    }

    func testTheCommonListIsInCirculationAndKnown() {
        let common = Currency.common
        XCTAssertGreaterThan(common.count, 100)
        XCTAssertTrue(common.contains(.usd))
        XCTAssertTrue(common.contains(.gbp))
        XCTAssertFalse(common.contains(Currency("DEM")), "the mark is not in circulation")
        /// The system's list and the pinned table drift on a handful of codes — a currency
        /// minted after the table (XCG), a few ICU still lists after retirement (HRK, SLL) —
        /// and a currency the table does not know is still two places, a name and a sign
        for currency in common {
            XCTAssertFalse(currency.narrowSymbol.isEmpty, currency.code)
            XCTAssertGreaterThanOrEqual(currency.decimals, 0)
        }
    }
}
