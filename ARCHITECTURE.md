# Calendrical Architecture — the kernel and the derived API

This document describes how Calendrical's calendars are constructed in 2.0: the kernel every calendar implements, the derived API that computes every other answer from it, the five makers that build calendars, and the conventions that hold the system together. It is a maintainer's map, not user documentation; the guides and module docs cover usage.

## The kernel

A calendar is a module that implements Elixir's `Calendar` behaviour and the eight callbacks of the `Calendrical` behaviour. Six `Calendar` callbacks are the primitives a calendar states for itself: `leap_year?/1`, `months_in_year/1`, `days_in_month/2`, `valid_date?/3`, `year_of_era/3` and `day_of_era/3`. The `Calendrical` kernel is `info/0`, the static facts about the calendar as a `Calendrical.Info` struct; `date_to_iso_days/3` and `date_from_iso_days/1`, the spine every conversion runs through; `leap_month/1`, the position of a year's leap month; `written_date/3` and `date_from_written_date/3`, the figures a date is written with and the date those figures name; and `shift/6` and `diff/3`, positional arithmetic under one clamping contract.

`info/0` is where a fact lives rather than a function: the CLDR calendars that name the months and the eras, the epoch, whether there is a year 0, the fewest and most months a year has, the rule the calendar's own weeks follow, the cycles its years run in, the place an astronomical calendar is reckoned at, the lengths its months can have, the calendar its dates are parsed in, and a composite's members. Every maker builds the struct once, at compile time, from its options.

## The derived API

Every other answer is computed from the kernel by plain functions that take the calendar module first: `Calendrical.Month` (CLDR months from the leap month and the written date, traditional months, month and day numbers, lengths declared or sampled and cached), `Calendrical.Week` (TR35 whole weeks from `info().weeks` and the year's bounds, the day of the week, week dates), `Calendrical.Period` (the days of a year and a month, quarters, quadrimesters and semesters, the day of the year, the days in a year), `Calendrical.Era` (the year and day of era by the era calendar and the year-zero rule, the extended, related Gregorian and cyclic years) and `Calendrical.Shift` (the positional arithmetic `use Calendrical.Calendar` supplies). `Calendrical.Info` answers the composite questions from the member table: the calendar in effect on a date, its CLDR type and its parsing calendars.

`Calendrical.Compiler.StandardCallbacks` is the one generator that puts those answers on a calendar module as one-line delegations, so Localize, which can only call a calendar by `calendar.function(...)`, asks any calendar any question. Every delegation is final; only the kernel trio with defaults there (`leap_month/1`, `written_date/3`, `date_from_written_date/3`), the two era primitives and `diff/3` may be overridden, and `Calendrical.Compiler.DateCheck` guards the era primitives so an override answers `{:error, :invalid_date}` for a date the calendar lacks and a `Calendrical.MissingFieldsError` for a missing field, as every derived function does itself. A question that needs no day is answered for a month's 1st where the month has days but begins later, as England's March 1751 does.

## The makers

| Maker | Builds | Kernel from |
|---|---|---|
| `use Calendrical.Calendar` | the hand-written calendars: Gregorian and ISO (over `Calendar.ISO`), Julian, Coptic, Ethiopic, Persian, Hebrew, the Islamic calendars, Buddhist, Roc, Indian, Japanese, Sweden's transitional calendar | the author's spine and primitives; `shift/6` from `Calendrical.Shift` |
| `use Calendrical.Calendar.Shifted` | a year begun elsewhere in a base calendar's year: the fiscal years, `Calendrical.new/3` month calendars, the locale's Gregorian calendars, the Julian year-start variants | the base's date relabelled, with a split month where the year begins within a base month |
| `use Calendrical.Calendar.Weeks` | a year of whole weeks cut into months by a pattern: ISOWeek, NRF, `Calendrical.new/3` week calendars | the week engine in `Calendrical.Base.Week`, driven by `Calendrical.Config` |
| `use Calendrical.Calendar.Lunisolar` | Chinese, Korean, Vietnamese, LunarJapanese | `Calendrical.Lunisolar`, parametrised by epoch and location |
| `use Calendrical.Composite` | calendars in sequence: England, Sweden, Japan | the member in effect, from the segment table in `info().members` |

Each maker refuses an option it does not read at compile time. The options are the facts of `info/0` in the words the plan settled: `months_in_year: {12, 13}`, `weeks: [first_day: 7, min_days_in_first_week: 1]` or `:from_first_day`, `year_begins: {10, 1}`, `year_number: :majority`, `written_year: :label`, `pattern: [4, 5, 4]`, `year_ends: {:saturday, :nearest, {1, 31}}`.

## Data conventions

* **A date is its calendar's own fields.** A week calendar's date is a year, a month of its pattern and a day of that month; a shifted calendar's a label year, a counted month and a day; a lunisolar calendar's a year, a position and a day. `written_date/3` is the one place a date's figures differ from its fields: a fiscal date writes the Gregorian month and year, a Julian year-start variant its label year with the Julian month, a lunisolar calendar its traditional month.

* **Names are CLDR's index; figures are the calendar's.** `Calendrical.Month.cldr_month/3` derives the name of a month from its traditional number, which is the identity in every CLDR calendar but the Hebrew, where CLDR numbers Adar I on its own and ICU writes the figure as the position in the year.

* **`iso_days` is a bare integer day number**, the proleptic Gregorian count `Calendar.ISO` uses, except in the `naive_datetime_*` plumbing where it is the stdlib's `{days, day_fraction}` pair.

* **Lengths without a year are declared or sampled.** `info().month_lengths` states them where a calendar's months are expensive, as the sighting calendars'; otherwise `Calendrical.Month.lengths/1` samples one cycle of years, or thirty, once, and the laws test holds every declared table to the sampler.

* **Era data is runtime-resolved.** `Calendrical.Era` reads CLDR era data on first use and caches it in `:persistent_term`.

## Runtime calendar creation

`Calendrical.new/3`, `Calendrical.FiscalYear.calendar_for/1` and `Calendrical.calendar_for_territory/1` create month and week calendars at runtime by `use`ing the Shifted or Weeks maker in a module created through the `Calendrical.Compiler` server, which serialises creation so concurrent callers get one module; `Calendrical.Composite.new/2` and `Calendrical.Reform.calendar_for/1` do the same for composites. An invalid option is the maker's `ArgumentError`, returned as `{:error, exception}`.

## Known debt

* The week engine, `Calendrical.Base.Week` with `Calendrical.Config`, still carries the week calendars' arithmetic in the pre-2.0 shape behind `Calendrical.Calendar.Weeks`; its collapse onto the kernel is the one piece of the redesign left for after 2.0.

* Multi-month arithmetic on week calendars is O(n): the engine adds months one at a time because leap-week accounting across long years has no closed form in the current implementation.
