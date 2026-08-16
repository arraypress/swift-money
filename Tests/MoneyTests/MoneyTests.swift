//
//  MoneyTests.swift
//  Money
//
//  Created by David Sherlock on 2026.
//

import Foundation
import XCTest
@testable import Money

final class MoneyTests: XCTestCase {

    // MARK: Counting in the smallest unit

    func testAnAmountIsItsMinorUnits() {
        XCTAssertEqual(Money("12.34", in: .gbp)?.units, 1234)
        XCTAssertEqual(Money("1000", in: .jpy)?.units, 1000)
        XCTAssertEqual(Money("1.234", in: Currency("KWD"))?.units, 1234)
    }

    func testTheSameIntegerIsDifferentMoney() {
        // £12.34 and ¥1,234 are both 1234 units, which is why the currency
        // is not optional anywhere in this package.
        XCTAssertEqual(Money(units: 1234, in: .gbp).decimalString, "12.34")
        XCTAssertEqual(Money(units: 1234, in: .jpy).decimalString, "1234")
    }

    func testTheClassicFloatingPointFailureDoesNotHappen() {
        // 0.1 + 0.2 is 0.30000000000000004 in binary floating point, and a
        // system that adds a thousand invoice lines that way eventually
        // disagrees with a bank by a penny nobody can find.
        let sum = Money("0.1", in: .gbp)! + Money("0.2", in: .gbp)!
        XCTAssertEqual(sum.units, 30)
        XCTAssertEqual(sum.decimalString, "0.30")
    }

    func testDecimalStringRoundTrips() {
        for text in ["0.00", "0.01", "12.34", "1234.56", "-12.34", "999999.99"] {
            XCTAssertEqual(Money(text, in: .gbp)?.decimalString, text, text)
        }
        XCTAssertEqual(Money("1000", in: .jpy)?.decimalString, "1000")
        XCTAssertEqual(Money("1.234", in: Currency("KWD"))?.decimalString, "1.234")
    }

    func testAmountsSmallerThanOneUnitReadCorrectly() {
        XCTAssertEqual(Money(units: 5, in: .gbp).decimalString, "0.05")
        XCTAssertEqual(Money(units: -5, in: .gbp).decimalString, "-0.05")
        XCTAssertEqual(Money(units: 1, in: Currency("KWD")).decimalString, "0.001")
    }

    // MARK: Reading what people write

    func testWhatIsAccepted() {
        XCTAssertNotNil(Money("12.34", in: .gbp))
        XCTAssertNotNil(Money("12", in: .gbp))
        XCTAssertNotNil(Money("12.3", in: .gbp))
        XCTAssertNotNil(Money("-12.34", in: .gbp))
        XCTAssertNotNil(Money("+12.34", in: .gbp))
        XCTAssertNotNil(Money(" 12.34 ", in: .gbp))
        XCTAssertEqual(Money("12.3", in: .gbp)?.units, 1230, "a short fraction is padded, not truncated")
    }

    func testWhatIsRefused() {
        // Deliberately strict. "1.234" means one thing in Britain and another
        // in Germany, and a library that guesses is wrong by a factor of a
        // thousand once a year.
        XCTAssertNil(Money("1,234.56", in: .gbp), "thousands separators")
        XCTAssertNil(Money("£12.34", in: .gbp), "symbols")
        XCTAssertNil(Money("12.34.56", in: .gbp))
        XCTAssertNil(Money("twelve", in: .gbp))
        XCTAssertNil(Money("", in: .gbp))
        XCTAssertNil(Money("   ", in: .gbp))
    }

    func testMoreDecimalsThanTheCurrencyHasIsRefused() {
        // Deciding whether ¥1000.50 is 1000 or 1001 is deciding what
        // somebody's invoice says.
        XCTAssertNil(Money("1000.50", in: .jpy))
        XCTAssertNil(Money("12.345", in: .gbp))
        XCTAssertNil(Money("1.2345", in: Currency("KWD")))
        XCTAssertNotNil(Money("1.234", in: Currency("KWD")))
    }

    func testAnAbsurdAmountIsRefusedRatherThanWrapped() {
        XCTAssertNil(Money("99999999999999999999", in: .gbp))
    }

    // MARK: From a decimal

    func testADecimalIsRoundedToWhatTheCurrencyCanHold() {
        // Twenty per cent of 1234.56 is 246.912, and it has to become
        // something chargeable before it can be charged.
        XCTAssertEqual(Money(Decimal(string: "246.912")!, in: .gbp).units, 24691)
        XCTAssertEqual(Money(Decimal(string: "1000.5")!, in: .jpy, rounding: .half).units, 1001)
        XCTAssertEqual(Money(Decimal(string: "1000.5")!, in: .jpy, rounding: .down).units, 1000)
    }

    func testTheDecimalComesBack() {
        XCTAssertEqual(Money("12.34", in: .gbp)?.decimal, Decimal(string: "12.34"))
        XCTAssertEqual(Money("1000", in: .jpy)?.decimal, Decimal(1000))
    }
}
