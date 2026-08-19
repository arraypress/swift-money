//
//  Formatting.swift
//  Money
//
//  Created by David Sherlock on 2026.
//
//  Printing an amount for a person.
//
//  Delegated to Foundation, deliberately. Where the symbol goes, what
//  separates the thousands, whether the minus sign leads or the amount sits
//  in brackets — all of that is locale data that ships with the operating
//  system and is more current than any table a library could carry.
//
//  What this package does not delegate is the arithmetic and the number of
//  decimal places, because those decide what the amount *is* rather than how
//  it looks.
//

import Foundation

extension Money: CustomStringConvertible {

    /// The amount and its code: `GBP 1234.56`. Unambiguous, and not for a
    /// customer to read.
    public var description: String { "\(currency.code) \(decimalString)" }
}

extension Money {

    /// The amount as somebody in `locale` would read it: `£1,234.56`,
    /// `1.234,56 €`, `¥1,000`.
    ///
    /// The default follows the machine, which is right for a screen and
    /// wrong for a record: the same program prints the same amount two ways
    /// on two laptops. A document meant to come out identical wherever it is
    /// generated should pass its locale rather than inherit one.
    public func formatted(in locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency.code
        formatter.minimumFractionDigits = currency.decimals
        formatter.maximumFractionDigits = currency.decimals

        return formatter.string(from: decimal as NSDecimalNumber)
            ?? "\(currency.symbol)\(decimalString)"
    }

    /// The amount with its code rather than its symbol: `GBP 1,234.56`.
    ///
    /// What a document crossing a border wants. `$1,234.56` is four
    /// currencies, and a customer in Toronto reading an invoice from Sydney
    /// should not have to guess which.
    public func formattedWithCode(in locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency.code
        formatter.currencySymbol = currency.code + " "
        formatter.minimumFractionDigits = currency.decimals
        formatter.maximumFractionDigits = currency.decimals

        // The appended space separates the code where the locale prefixes
        // its symbol — `GBP 1,234.56` — and becomes a stray trailing space
        // where the locale suffixes it instead. Trimmed rather than
        // special-cased per locale.
        let text = formatter.string(from: decimal as NSDecimalNumber)
            ?? "\(currency.code) \(decimalString)"
        return text.trimmingCharacters(in: .whitespaces)
    }
}
