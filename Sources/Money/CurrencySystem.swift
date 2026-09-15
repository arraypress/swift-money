//
//  CurrencySystem.swift
//  Money
//
//  What the operating system knows about a currency that arithmetic does not
//  need: its name in the user's language, the symbol it is written with, and
//  which currencies are in circulation at all.
//

import Foundation

extension Currency {

    /// The currency's own symbol — `$`, `£`, `฿`, `¥` — the way its own
    /// speakers write it, whatever the user's locale.
    ///
    /// ``symbol`` asks the current locale, which is right for a receipt and
    /// wrong for a label: a British Mac writes the dollar as `US$`, because
    /// to a British reader a bare `$` is ambiguous. A metric that says
    /// "Bitcoin in dollars" wants the dollar sign. This is ICU's narrow
    /// presentation, which is that sign, read from the system rather than a
    /// table that goes stale. A code the system has no symbol for reads as
    /// the code.
    public var narrowSymbol: String {
        guard code.count == 3, code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return code }
        let rendered = Decimal(0).formatted(.currency(code: code).presentation(.narrow).precision(.fractionLength(0)))
        let stripped = rendered.filter { !$0.isNumber && !$0.isWhitespace && $0 != "." && $0 != "," }
        return stripped.isEmpty ? code : stripped
    }

    /// The currency's name in a language — "Thai Baht", "Euro" — or nil for
    /// a code the system does not know.
    public func localizedName(in locale: Locale = .current) -> String? {
        locale.localizedString(forCurrencyCode: code)
    }

    /// The currencies in circulation, as the system lists them: the ones a
    /// person can be paid in today, without the retired and the special
    /// codes ``known`` has to carry for old documents.
    public static var common: [Currency] {
        Locale.commonISOCurrencyCodes.map { Currency($0) }
    }
}
