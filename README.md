# Swift Money

Money as an integer count of the smallest unit that exists, with the arithmetic that keeps it exact.

```swift
let price = Money("1234.56", in: .gbp)!      // 123,456 pennies
let vat   = price.percentage(20)             // £246.91, rounded once, at the end
let total = price + vat                      // £1,481.47

total.allocate(3).map(\.decimalString)       // ["493.83", "493.82", "493.82"] — adds back up
total.formatted(in: Locale(identifier: "en_GB"))   // "£1,481.47"
```

## Why

`0.1 + 0.2` is `0.30000000000000004`. A system that adds a thousand invoice lines in binary floating point eventually disagrees with somebody's bank by a penny nobody can find, and finding it costs more than the penny.

`Decimal` is exact and fixes that half. This goes further for one reason: the question money actually asks is *how many pennies*, and an integer answers it without a scale to get wrong. £12.34 is 1234. ¥1000 is 1000. A Kuwaiti dinar of 1.234 is 1234 fils. Every operation here is integer arithmetic, and rounding happens in exactly one place — where you divide, which is where money is actually lost.

## Features

- 🪙 **Exact** — integers throughout; no float anywhere near an amount
- 🌍 **Every currency's own precision** — the yen has no minor unit, the dinar has three, and both are wrong by default when you assume two
- ➗ **Allocation that loses nothing** — a pound in three is 34p, 33p, 33p, and the shares add back to a pound
- 🧾 **Tax both ways** — a percentage added, and the tax *inside* a gross figure, which is the calculation people get backwards
- 🖨️ **Printed by the system** — symbols, separators and placement come from Foundation, which is more current than any table
- 🚫 **Refuses to guess** — no thousands separators, no symbols, no locale-sniffing on input, and no adding dollars to euros
- 🪶 **No dependencies** — Foundation, and nothing else

## Amounts

```swift
Money("12.34", in: .gbp)          // exact, read digit by digit
Money(units: 1234, in: .gbp)      // the same thing, said directly
Money(Decimal(string: "246.912")!, in: .gbp)   // rounded to £246.91, deliberately
```

`Money("12.34", in: .gbp)` is `nil` for anything that is not a plain decimal number — `1,234.56`, `£12.34`, `twelve` — and for anything finer than the currency. `Money("1000.50", in: .jpy)` is nothing, because half a yen is not an amount anybody can pay, and deciding whether it becomes 1000 or 1001 is deciding what somebody's invoice says.

Text typed by a person should be parsed with a locale by whatever collected it. `1.234` means one thing in Britain and another in Germany, and a library that guesses is wrong by a factor of a thousand once a year.

## Decimals, and whose answer to believe

The number of places a currency has is not a display preference — it is the size of the smallest amount that exists.

ICU, which ships with the operating system, reports what people *do*: nobody quotes fractions of a forint, so it says zero. ISO 4217 records what the currency *is*, and that is what e-invoicing schemas and banks reference. **This library follows the standard**, because an invoice is a record rather than a shopfront — and a test cross-checks the pinned table against ICU on every run, listing the seventeen currencies where they knowingly differ. When ICU drifts somewhere new, the test says so; it does not turn up in somebody's accounts.

The table is pinned rather than read from the system for one more reason: ICU data changes with OS versions, and a document that has to render identically for seven years cannot depend on which Mac wrote it.

## Dividing

```swift
Money("1.00", in: .gbp)!.allocate(3)
// 34p, 33p, 33p

Money("10.00", in: .gbp)!.allocate(ratios: [1, 1, 2])
// £2.50, £2.50, £5.00 — a discount spread across lines by value
```

Not three lots of 33.3p, and not three lots of 33p with a penny left in the machine. The remainder goes out a unit at a time, to the shares that lost most to truncation. Every division adds back to what you started with — there is a test that checks it for every amount and every split from one to twelve.

## Tax

```swift
net.adding(percent: 20)          // net → gross
gross.taxIncluded(at: 20)        // the tax *inside* a gross figure
```

£120 including 20% holds £20 of tax, not £24. It is the commonest mistake in a spreadsheet full of invoices, which is why it is a method here rather than something everybody reimplements.

## Requirements

- macOS 14+ / iOS 17+
- Swift 6

## License

MIT — see [LICENSE](LICENSE).
