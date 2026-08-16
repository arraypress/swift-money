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
    public static func * (money: Money, times: Int) -> Money {
        Money(units: money.units * times, in: money.currency)
    }

    public static func * (times: Int, money: Money) -> Money { money * times }

    /// Everything in the sequence, added up.
    ///
    /// - Returns: Nothing for an empty sequence — there is no zero without a
    ///   currency to be zero in, and picking one would be inventing an
    ///   answer.
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
        NSDecimalRound(&rounded, &product, 0, rounding.foundation)

        return Money(units: NSDecimalNumber(decimal: rounded).intValue, in: currency)
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
        NSDecimalRound(&rounded, &product, 0, rounding.foundation)

        return Money(units: NSDecimalNumber(decimal: rounded).intValue, in: currency)
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
    /// - Returns: An empty array when the ratios are empty or sum to nothing.
    public func allocate(ratios: [Int]) -> [Money] {
        let total = ratios.reduce(0, +)
        guard !ratios.isEmpty, total > 0 else { return [] }

        var shares = ratios.map { units * $0 / total }
        var remainder = units - shares.reduce(0, +)

        // Ordered by what each share lost to truncation, so the money goes
        // where it was nearest to being owed.
        let owed = ratios.indices
            .map { (index: $0, fraction: units * ratios[$0] % total) }
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
