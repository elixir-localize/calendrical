# Calendrical usage rules

Rules for LLM coding agents using `calendrical` as a dependency. Not exhaustive — see the HexDocs guides for full reference.

## What this package is for

Calendrical extends Elixir's `Calendar`, `Date` and `DateTime` with the calendar systems used around the world: Gregorian, Buddhist, Japanese imperial, Islamic (tabular and observational), Persian, Hebrew, ROC, Coptic and more. It also covers month- and week-based calendars, fiscal years, and calendar arithmetic.

It is built on [`localize`](https://hex.pm/packages/localize), which supplies the CLDR data.

## Core conventions

* Public functions return `{:ok, result}` or `{:error, exception}`. Pattern match with `case`/`with`; do not use `try/rescue`.

* Locale identifiers follow Localize's conventions — atoms in canonical BCP 47 form (`:en`, `:"en-AU"`), or strings, validated on the way in.

* A calendar is an Elixir calendar *module* (`Calendar.ISO`, `Calendrical.Japanese`), not an atom name. Get one from a locale rather than hard-coding it.

## Module map

| Task | Use |
|---|---|
| Parse a localized date string | `Calendrical.Date.parse/2` |
| Parse a localized time string | `Calendrical.Time.parse/2` |
| Parse a localized datetime string | `Calendrical.DateTime.parse/2` |
| Parse anything of the above, dispatching on shape | `Calendrical.parse/2` |
| Resolve the calendar a locale or territory implies | `Calendrical.calendar_from_locale/1`, `calendar_from_territory/1` |
| Date/time intervals and ranges | `Calendrical.Interval` |
| Calendar reform dates (Julian → Gregorian) | `Calendrical.Reform` |

## Common idioms

Parse a date the way a user in that locale would write it:

```elixir
{:ok, date} = Calendrical.Date.parse("22.03.2026", locale: :de)
{:ok, date} = Calendrical.Date.parse("March 22, 2026", locale: :en)
```

`parse/2` accepts the locale's CLDR short, medium, long and full patterns as well as ISO 8601 — do not require the user to type ISO.

Partial input is supported where it makes sense; `Calendrical.Time.parse/2` accepts `as: :map` and returns the components it could read, which is what a form field needs while the user is still typing.

## The relationship with Localize

* **Localize formats and parses.** `Localize.Date.to_string/2` renders a date and `Localize.Date.parse/2` reads one back. Calendrical's parse functions delegate to Localize's: `Calendrical.parse/2` to `Localize.DateTime.Parser.parse/2`, `Calendrical.Date.parse/2` to `Localize.Date.parse/2`, `Calendrical.Date.parse_range/2` to `Localize.Interval.parse/2`, and `Calendrical.Time.parse/2` and `Calendrical.DateTime.parse/2` to `Localize.Time.parse/2` and `Localize.DateTime.parse/2`.

* Results and errors are Localize's, so match on `Localize.DateParseError`, `Localize.TimeParseError`, `Localize.DateTimeParseError` and `Localize.DateRangeParseError`.

* Calendrical supplies the calendar modules parsed dates are returned in and `Calendrical.TimeZone` for named time zones. Localize reaches both at runtime, because Calendrical depends on Localize and cannot be depended on in return.

* Either entry point is fine; they give identical results.

## Things not to do

* Do not hand-roll date parsing with `String.split/2` and `String.to_integer/1`. Field order differs by locale — `22.03.2026` is 22 March in `de` and would be nonsense read as US order.

* Do not assume the Gregorian calendar. `Calendrical.calendar_from_locale/1` tells you what the locale actually uses; several locales default to a non-Gregorian calendar.

* Do not convert between calendars by adding or subtracting a fixed offset. Use the calendar modules; year lengths and epochs differ.

* Do not use `Date.from_iso8601/1` on user input in a localized form. It only accepts ISO.
