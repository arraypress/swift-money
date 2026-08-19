//
//  Arithmetic.swift
//  Money
//
//  Created by David Sherlock on 2026.
//
//  Adding money up, and the one hard part: dividing it.
//
//  Addition is integers and needs no comment. Division is where money is
//  actually lost — three ways of a pound is 33.333 pence each, and a system
//  that rounds each share and moves on has thrown a penny away. Which is why
//  ``Money/allocate(_:)`` exists and why plain division does not.
//
//  Overflow traps, the way Swift's own integers trap: an amount past nine
//  quintillion minor units is arithmetic gone wrong, not an amount, and a
//  crash at the sum names the fault where returning a wrapped number would
//  smuggle it into an account. The conversions that take numbers from
//  outside — parsing, `init(exactly:)` — refuse instead, because outside
//  numbers are not arithmetic gone wrong, they are input.
//

import Foundation

// MARK: - Adding up

extension Money {

    public static func + (left: Money, right: Money) -> Money {
        precondition(left.currency == right.currency, Money.mixed(left, right))
        return Money(units: left.units + right.units, in: left.currency)
    }

    public static func - (left: Money, right: Money) -> Money {
        precondition(left.currency == right.currency, Money.mixed(left, right))
        return Money(units: left.units - right.units, in: left.currency)
    }

    public static prefix func - (value: Money) -> Money {
        Money(units: -value.units, in: value.currency)
    }

    public static func += (left: inout Money, right: Money) { left = left + right }
    public static func -= (left: inout Money, right: Money) { left = left - right }

    /// A whole number of them.
    ///
    /// Traps on overflow like `+` does. A quantity that arrived from a file
    /// rather than from your own arithmetic should be range-checked by
    /// whatever read it, the way it validates everything else it reads.
    public static func * (money: Money, times: Int) -> Money {
        Money(units: money.units * times, in: money.currency)
    }

    public static func * (times: Int, money: Money) -> Money { money * times }

    /// Everything in the sequence, added up.
    ///
    /// - Returns: Nothing for an empty sequence — there is no zero without a
    ///   currency to be zero in, and picking one would be inventing an
    ///   answer.
    /// - Precondition: Everything in it is in the same currency, since this
    ///   is `+` in a loop and `+` will not mix them. Check before totalling
    ///   anything assembled from a file, rather than after.
    public static func total<S: Sequence>(_ amounts: S) -> Money? where S.Element == Money {
        var iterator = amounts.makeIterator()
        guard var sum = iterator.next() else { return nil }
        while let next = iterator.next() { sum += next }
        return sum
    }

    static func mixed(_ left: Money, _ right: Money) -> String {
        "Cannot add \(left.currency) to \(right.currency). Two currencies are two amounts, and "
            + "turning one into the other needs a rate and a date that this does not have."
    }
}

// MARK: - Adding up a column of them

extension Sequence where Element == Money {

    /// Everything in it, added up.
    ///
    /// Reads the way the thing being done reads — `lines.map(\.amount).total`
    /// rather than `Money.total(lines.map(\.amount))` — and, being written on
    /// a sequence of `Money` rather than on `Sequence`, it appears only where
    /// there is money to add. A library that puts `.money` on every `String`
    /// in a program is charging everybody for a convenience one file wanted.
    ///
    /// - Returns: Nothing for an empty sequence — there is no zero without a
    ///   currency to be zero in.
    public var total: Money? { Money.total(self) }

    /// Everything in it, added up, in a currency stated rather than inferred.
    ///
    /// The form for a column of figures that came from somewhere: it knows
    /// what the total is supposed to be in, so an empty list is zero in that
    /// currency instead of nothing, and a stray amount in another one is a
    /// refusal instead of a stopped process.
    ///
    /// - Returns: Nothing if anything in it is in a different currency.
    public func total(in currency: Currency) -> Money? {
        var sum = Money.zero(currency)
        for amount in self {
            guard amount.currency == currency else { return nil }
            sum += amount
        }
        return sum
    }
}

extension Money: Comparable {

    public static func < (left: Money, right: Money) -> Bool {
        precondition(left.currency == right.currency, Money.mixed(left, right))
        return left.units < right.units
    }
}

// MARK: - Taking a percentage

extension Money {

    /// A percentage of this amount, rounded to a real unit.
    ///
    /// Computed in minor units so the arithmetic is exact until the last
    /// step: 20% of £1,234.56 is 24,691.2 pence, and only that final rounding
    /// is a decision.
    public func percentage(_ percent: Decimal, rounding: RoundingMode = .half) -> Money {
        var product = Decimal(units) * percent / 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &product, 0, rounding.foundation(for: product))

        return Money(units: unitsRefusingToWrap(rounded, taking: "\(percent)%"), in: currency)
    }

    /// This amount plus a percentage of it — a net figure made gross.
    public func adding(percent: Decimal, rounding: RoundingMode = .half) -> Money {
        self + percentage(percent, rounding: rounding)
    }

    /// The tax inside an amount that already includes it.
    ///
    /// £120 including 20% holds £20 of tax, not £24 — the commonest mistake
    /// in a spreadsheet full of invoices, and the reason this is a method
    /// rather than something everybody reimplements.
    public func taxIncluded(at percent: Decimal, rounding: RoundingMode = .half) -> Money {
        let divisor = 100 + percent
        guard divisor != 0 else { return Money.zero(currency) }

        var product = Decimal(units) * percent / divisor
        var rounded = Decimal()
        NSDecimalRound(&rounded, &product, 0, rounding.foundation(for: product))

        return Money(units: unitsRefusingToWrap(rounded, taking: "the \(percent)% inside"), in: currency)
    }

    /// `rounded` as minor units, refusing to wrap.
    ///
    /// `NSDecimalNumber.intValue` hands back the low bits of anything too
    /// big as though they were the number — the same wrap ``init(exactly:in:rounding:)``
    /// refuses at the door. Arithmetic that outgrows what money can hold is a
    /// fault, and it traps the way an overflowing `+` does, rather than
    /// returning a smaller amount with the wrong sign.
    private func unitsRefusingToWrap(_ rounded: Decimal, taking what: String) -> Int {
        precondition(
            rounded >= Decimal(Int.min) && rounded <= Decimal(Int.max),
            "Taking \(what) of \(self) overflows: amounts run to about 9×10^18 minor units."
        )
        return NSDecimalNumber(decimal: rounded).intValue
    }
}

// MARK: - Dividing without losing any

extension Money {

    /// This amount split into `parts`, losing nothing.
    ///
    /// A pound in three is 34p, 33p, 33p — not three lots of 33.3p, and not
    /// three lots of 33p with a penny left in the machine. The remainder is
    /// handed out one unit at a time from the first share, which is what
    /// every accounting system does and what nobody implements correctly the
    /// first time.
    ///
    /// - Returns: An empty array for zero or fewer parts.
    public func allocate(_ parts: Int) -> [Money] {
        guard parts > 0 else { return [] }

        let base = units / parts
        var remainder = units - base * parts

        return (0..<parts).map { _ in
            var share = base
            if remainder > 0 { share += 1; remainder -= 1 }
            else if remainder < 0 { share -= 1; remainder += 1 }
            return Money(units: share, in: currency)
        }
    }

    /// This amount split in given proportions, losing nothing.
    ///
    /// For a discount spread across lines, or a shipping cost divided by
    /// weight. The shares are proportional and their total is exactly this
    /// amount — the remainder goes to the largest fractional part first,
    /// which is the fairest of the arbitrary choices.
    ///
    /// A negative ratio is taken as given, so long as the total stays
    /// positive: it is a row that owes rather than receives, its share comes
    /// out negative, and the shares still sum to exactly this amount.
    ///
    /// - Returns: An empty array when the ratios are empty or sum to nothing.
    public func allocate(ratios: [Int]) -> [Money] {
        let total = ratios.reduce(0, +)
        guard !ratios.isEmpty, total > 0 else { return [] }

        // Worked in `Decimal` rather than `Int`, because the obvious
        // `units * ratio / total` overflows long before either end of it is
        // an unreasonable number: a trillion of a four-place currency is
        // 10^16 minor units, and a ratio in the thousands takes the product
        // past Int64 — a crash on the way to a division that lands well
        // inside it.
        let scale = Decimal(total)
        let amount = Decimal(units)

        let exact = ratios.map { amount * Decimal($0) / scale }
        var shares = exact.map { value -> Int in
            var truncated = Decimal()
            var value = value
            NSDecimalRound(&truncated, &value, 0, .down)
            return NSDecimalNumber(decimal: truncated).intValue
        }
        var remainder = units - shares.reduce(0, +)

        // Ordered by what each share lost to truncation, so the money goes
        // where it was nearest to being owed.
        let owed = ratios.indices
            .map { (index: $0, fraction: exact[$0] - Decimal(shares[$0])) }
            .sorted { $0.fraction > $1.fraction }

        var index = 0
        while remainder != 0, !owed.isEmpty {
            let target = owed[index % owed.count].index
            shares[target] += remainder > 0 ? 1 : -1
            remainder += remainder > 0 ? -1 : 1
            index += 1
        }

        return shares.map { Money(units: $0, in: currency) }
    }
}
