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

* **Localize formats, Calendrical parses.** `Localize.Date.to_string/2` renders a date; `Calendrical.Date.parse/2` reads one back.

* Localize 1.2+ exposes `Localize.Date.parse/2`, `Localize.Time.parse/2` and `Localize.DateTime.parse/2` which delegate here. They resolve Calendrical **at runtime** and return `%Localize.DependencyRequiredError{}` when it is absent, because Calendrical depends on Localize and cannot be depended on in return.

* Either entry point is fine. Prefer the `Localize.*` one when the surrounding code is already Localize-flavoured, and the `Calendrical.*` one when you need options this package documents and Localize does not.

## Things not to do

* Do not hand-roll date parsing with `String.split/2` and `String.to_integer/1`. Field order differs by locale — `22.03.2026` is 22 March in `de` and would be nonsense read as US order.

* Do not assume the Gregorian calendar. `Calendrical.calendar_from_locale/1` tells you what the locale actually uses; several locales default to a non-Gregorian calendar.

* Do not convert between calendars by adding or subtracting a fixed offset. Use the calendar modules; year lengths and epochs differ.

* Do not use `Date.from_iso8601/1` on user input in a localized form. It only accepts ISO.
