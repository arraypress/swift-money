//
//  Money.swift
//  Money
//
//  Created by David Sherlock on 2026.
//
//  An amount of money, counted in the smallest unit that exists.
//
//  Not a Double: 0.1 + 0.2 is 0.30000000000000004, and a system that adds up
//  a thousand invoice lines that way is a system that eventually disagrees
//  with somebody's bank by a penny nobody can find.
//
//  Not a Decimal either, though Decimal is exact — because the question money
//  actually asks is "how many pennies", and an integer answers it without a
//  scale to get wrong. £12.34 is 1234 pennies. ¥1000 is 1000 yen. A dinar of
//  1.234 is 1234 fils. Every operation here is integer arithmetic, and the
//  only place rounding happens is where it must: dividing.
//

import Foundation

/// An amount in one currency.
public struct Money: Sendable, Hashable, Codable {

    /// The amount, in the currency's smallest unit — pennies, cents, yen,
    /// fils. Negative for a credit.
    public let units: Int

    public let currency: Currency

    /// An amount given directly in minor units.
    ///
    /// `Money(units: 1234, in: .gbp)` is £12.34, and `Money(units: 1234, in:
    /// .jpy)` is ¥1,234 — the same integer means different money, which is
    /// why the currency is not optional.
    public init(units: Int, in currency: Currency) {
        self.units = units
        self.currency = currency
    }

    /// An amount written the way a person writes it: `12.34`, `1000`, `1.234`.
    ///
    /// Exact, because the string is read digit by digit rather than through a
    /// binary float. `Money("0.1", in: .gbp)! + Money("0.2", in: .gbp)!` is
    /// exactly thirty pence.
    ///
    /// - Returns: `nil` when the text is not a plain decimal number, or is
    ///   finer than the currency — `Money("1000.50", in: .jpy)` is nothing,
    ///   because half a yen is not an amount anybody can pay.
    public init?(_ text: String, in currency: Currency) {
        guard let parsed = Money.units(of: text, decimals: currency.decimals) else { return nil }
        self.units = parsed
        self.currency = currency
    }

    /// An amount from a decimal, rounded to what the currency can express.
    ///
    /// Rounding is stated rather than assumed: twenty per cent of £1,234.56
    /// is £246.912, which has to become £246.91 before it can be charged, and
    /// the caller should be able to say which way that goes.
    public init(_ value: Decimal, in currency: Currency, rounding: RoundingMode = .bankers) {
        var scaled = value * Decimal(currency.unitsPerMajor)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, rounding.foundation)

        self.units = NSDecimalNumber(decimal: rounded).intValue
        self.currency = currency
    }

    /// Nothing, in a currency.
    public static func zero(_ currency: Currency) -> Money {
        Money(units: 0, in: currency)
    }

    // MARK: Reading it back

    /// The amount as a plain decimal string: `12.34`, `1000`, `1.234`.
    ///
    /// No symbol, no separators, a full stop — what a schema wants, and what
    /// survives being read by something that is not a person.
    public var decimalString: String {
        let negative = units < 0
        let magnitude = abs(units)

        guard currency.decimals > 0 else { return "\(negative ? "-" : "")\(magnitude)" }

        let divisor = currency.unitsPerMajor
        let major = magnitude / divisor
        let minor = magnitude % divisor

        let padded = String(minor).leftPadded(to: currency.decimals, with: "0")
        return "\(negative ? "-" : "")\(major).\(padded)"
    }

    /// The amount as a `Decimal`, for handing to something that wants one.
    public var decimal: Decimal {
        Decimal(units) / Decimal(currency.unitsPerMajor)
    }

    public var isZero: Bool { units == 0 }
    public var isNegative: Bool { units < 0 }
    public var magnitude: Money { Money(units: abs(units), in: currency) }
}

// MARK: - Rounding

extension Money {

    /// Which way a division goes when it lands between two units.
    public enum RoundingMode: String, Sendable, CaseIterable, Codable {

        /// Half away from zero: 2.5 → 3, −2.5 → −3. What most invoices and
        /// most people expect, and what tax authorities usually specify.
        case half

        /// Half to the nearer even number: 2.5 → 2, 3.5 → 4. Spreads the
        /// error rather than always favouring one side, which matters when
        /// rounding thousands of lines.
        case bankers

        /// Toward zero, always.
        case down

        /// Away from zero, always.
        case up

        var foundation: NSDecimalNumber.RoundingMode {
            switch self {
            case .half: return .plain
            case .bankers: return .bankers
            case .down: return .down
            case .up: return .up
            }
        }
    }
}

// MARK: - Parsing

extension Money {

    /// Reads `12.34` into minor units, exactly.
    ///
    /// Deliberately strict: digits, one optional sign, one optional full stop.
    /// No thousands separators, no currency symbols, no comma decimals —
    /// because `1.234` means one thing in Britain and another in Germany, and
    /// a library that guesses which is a library that is wrong by a factor of
    /// a thousand once a year. Text that came from a person should be parsed
    /// with a locale by whatever collected it.
    static func units(of text: String, decimals: Int) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var negative = false
        var body = Substring(trimmed)
        if body.hasPrefix("-") { negative = true; body = body.dropFirst() }
        else if body.hasPrefix("+") { body = body.dropFirst() }

        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2, !parts.isEmpty else { return nil }

        let whole = parts[0]
        let fraction = parts.count == 2 ? parts[1] : ""

        guard !whole.isEmpty || !fraction.isEmpty,
              whole.allSatisfy(\.isNumber), fraction.allSatisfy(\.isNumber)
        else { return nil }

        // Finer than the currency is refused rather than rounded: deciding
        // whether ¥1000.50 is 1000 or 1001 is deciding what somebody's
        // invoice says, and this cannot know.
        guard fraction.count <= decimals else { return nil }

        let padded = fraction + String(repeating: "0", count: decimals - fraction.count)
        guard let major = Int(whole.isEmpty ? "0" : String(whole)),
              let minor = Int(padded.isEmpty ? "0" : padded)
        else { return nil }

        let (scaled, overflowed) = major.multipliedReportingOverflow(
            by: (0..<decimals).reduce(1) { total, _ in total * 10 }
        )
        guard !overflowed else { return nil }

        let (total, overflowedAgain) = scaled.addingReportingOverflow(minor)
        guard !overflowedAgain else { return nil }

        return negative ? -total : total
    }
}

private extension String {

    func leftPadded(to width: Int, with character: Character) -> String {
        count >= width ? self : String(repeating: character, count: width - count) + self
    }
}
