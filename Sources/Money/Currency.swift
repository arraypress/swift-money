//
//  Currency.swift
//  Money
//
//  Created by David Sherlock on 2026.
//
//  A currency, and the one fact about it that arithmetic needs.
//
//  How many decimal places a currency has is not a formatting preference: it
//  is the size of the smallest amount that exists. The yen has no minor unit,
//  so ¥1000.50 is not a price anybody can pay. The Kuwaiti dinar has three,
//  so rounding one to two places drops a fils — money going missing rather
//  than a display quibble.
//
//  Foundation knows this, through ICU, and knows it for all three hundred
//  codes. This carries its own table anyway, for one reason: ICU data ships
//  with the operating system, so the same program can format the same amount
//  differently on two machines. For a receipt that is untidy; for an invoice
//  that has to render identically for seven years, it is a defect. The table
//  is pinned here, and a test compares it against Foundation on every run —
//  so when ICU disagrees we find out and decide, rather than discovering it
//  in somebody's accounts.
//

import Foundation

/// A currency, by its ISO 4217 code.
public struct Currency: Sendable, Hashable, Codable, CustomStringConvertible,
                        ExpressibleByStringLiteral {

    /// The three-letter code, upper-cased: `GBP`, `JPY`, `KWD`.
    public let code: String

    /// Creates a currency from its code.
    ///
    /// An unrecognised code is allowed and treated as having two decimal
    /// places — a private settlement currency or one minted after this was
    /// written is not a reason to refuse to add up. ``isKnown`` says which
    /// you have.
    public init(_ code: String) {
        self.code = code.uppercased()
    }

    public var description: String { code }

    /// So a currency can be written as one: `let price = Money("12.34", in: "GBP")`.
    ///
    /// Safe as a literal because the initialiser takes any three letters —
    /// there is no failable case to hide, and a code the table has not caught
    /// up with behaves as an ordinary two-place currency rather than
    /// stopping. This is on `Currency` rather than on `String`: it is the
    /// place where a string is already known to be a currency code, which is
    /// the difference between an affordance and an imposition.
    public init(stringLiteral value: String) { self.init(value) }

    /// Whether this is a code the table knows.
    public var isKnown: Bool { Currency.places[code] != nil }

    /// How many decimal places amounts in this currency are written to.
    ///
    /// Two for anything unrecognised, which is right for almost every
    /// currency and quietly wrong for the two dozen that differ — hence the
    /// table rather than the assumption.
    public var decimals: Int { Currency.places[code] ?? 2 }

    /// How many minor units make one of the currency: 1 for the yen, 100 for
    /// the pound, 1000 for the dinar.
    public var unitsPerMajor: Int {
        (0..<decimals).reduce(1) { total, _ in total * 10 }
    }

    /// The symbol a reader expects, from the system rather than from a table
    /// — symbols are a display matter, and the system's are current.
    ///
    /// A code that is not three letters gets itself back rather than an
    /// answer from the system: asked for the symbol of `""`, Foundation
    /// returns the one for wherever the reader happens to be, so an amount
    /// in no currency at all printed as pounds in London and as dollars in
    /// New York.
    public var symbol: String {
        guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return code }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol ?? code
    }
}

// MARK: - The table

extension Currency {

    /// Decimal places by code, for everything that is not two.
    ///
    /// Kept as the exceptions rather than as three hundred rows: the list of
    /// currencies changes, the fact that most of them have two places does
    /// not, and a short table is one somebody can actually check.
    static let places: [String: Int] = {
        var table: [String: Int] = [:]

        // No minor unit at all.
        for code in ["BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW",
                     "PYG", "RWF", "UGX", "UYI", "VND", "VUV", "XAF", "XOF", "XPF"] {
            table[code] = 0
        }

        // Three.
        for code in ["BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND"] {
            table[code] = 3
        }

        // Four.
        for code in ["CLF", "UYW"] {
            table[code] = 4
        }

        // Everything ordinary, named so `isKnown` means something and so the
        // cross-check against Foundation has a set to walk.
        for code in ["AED", "AFN", "ALL", "AMD", "ANG", "AOA", "ARS", "AUD", "AWG", "AZN",
                     "BAM", "BBD", "BDT", "BGN", "BMD", "BND", "BOB", "BRL", "BSD", "BTN",
                     "BWP", "BYN", "BZD", "CAD", "CDF", "CHF", "CNY", "COP", "CRC", "CUP",
                     "CVE", "CZK", "DKK", "DOP", "DZD", "EGP", "ERN", "ETB", "EUR", "FJD",
                     "FKP", "GBP", "GEL", "GHS", "GIP", "GMD", "GTQ", "GYD", "HKD", "HNL",
                     "HTG", "HUF", "IDR", "ILS", "INR", "IRR", "JMD", "KES", "KGS", "KHR",
                     "KPW", "KYD", "KZT", "LAK", "LBP", "LKR", "LRD", "LSL", "MAD", "MDL",
                     "MGA", "MKD", "MMK", "MNT", "MOP", "MRU", "MUR", "MVR", "MWK", "MXN",
                     "MYR", "MZN", "NAD", "NGN", "NIO", "NOK", "NPR", "NZD", "PAB", "PEN",
                     "PGK", "PHP", "PKR", "PLN", "QAR", "RON", "RSD", "RUB", "SAR", "SBD",
                     "SCR", "SDG", "SEK", "SGD", "SHP", "SLE", "SOS", "SRD", "SSP", "STN",
                     "SVC", "SYP", "SZL", "THB", "TJS", "TMT", "TOP", "TRY", "TTD", "TWD",
                     "TZS", "UAH", "USD", "UYU", "UZS", "VES", "WST", "XCD", "YER", "ZAR",
                     "ZMW", "ZWG"] {
            table[code] = 2
        }

        return table
    }()

    /// Every code the table knows, sorted.
    public static var known: [Currency] {
        places.keys.sorted().map { Currency($0) }
    }
}

// MARK: - The ones worth naming

extension Currency {

    public static let gbp = Currency("GBP")
    public static let eur = Currency("EUR")
    public static let usd = Currency("USD")
    public static let chf = Currency("CHF")
    public static let jpy = Currency("JPY")
    public static let aud = Currency("AUD")
    public static let cad = Currency("CAD")
}
