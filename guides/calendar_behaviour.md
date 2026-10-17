# Making a calendar

This guide explains how to define a calendar in Calendrical 2.0: the kernel every calendar implements, the facts it states, the five makers that build calendars from those, and what a calendar may override.

## The kernel

A Calendrical calendar implements Elixir's `Calendar` behaviour and the eight callbacks of the `Calendrical` behaviour. Six `Calendar` callbacks are primitives the calendar states for itself: `leap_year?/1`, `months_in_year/1`, `days_in_month/2`, `valid_date?/3`, `year_of_era/3` and `day_of_era/3`. The `Calendrical` kernel is:

* `info/0` — the static facts about the calendar as a `Calendrical.Info` struct: the CLDR calendars that name its months and its eras, its epoch, whether it has a year 0, the fewest and the most months its years have, the rule its own weeks follow, the cycles its years run in, the place an astronomical calendar is reckoned at, the lengths its months can have, the calendar its dates are parsed in and, for a composite, its members.

* `date_to_iso_days/3` and `date_from_iso_days/1` — the spine every conversion runs through: a date of the calendar to the proleptic Gregorian day count `Calendar.ISO` uses, and back.

* `leap_month/1` — the position in a year of its leap month, or `nil`.

* `written_date/3` and `date_from_written_date/3` — the figures a date is written with and the date those figures name. A fiscal date is written as the Gregorian date it is; a Hebrew date writes its month's place in the year, as ICU does; most calendars write their own fields.

* `shift/6` and `diff/3` — the calendar's arithmetic in years, quarters, months, weeks and days, under one clamping contract: with `clamp: true`, the default, a day the month reached lacks becomes its last day, a traditional month the year reached lacks becomes the month it repeats, and a count across a missing year 0 goes a year further.

Every other answer is derived from the kernel and the primitives by the derived API, `Calendrical.Month`, `Calendrical.Week`, `Calendrical.Period`, `Calendrical.Era` and `Calendrical.Shift`, plain functions that take the calendar first. Every calendar also carries those answers as functions of its own module, so a consumer that holds only a calendar module, as Localize does, asks it any question:

    iex> Calendrical.Hebrew.month_of_year(5786, 7, 1)
    8

    iex> Calendrical.Month.cldr_month(Calendrical.Hebrew, 5786, 7)
    8

## `use Calendrical.Calendar`: a hand-written calendar

The maker for a calendar whose spine the author writes.

```elixir
defmodule MyApp.Julian do
  use Calendrical.Calendar,
    epoch: ~D[0001-01-01 Calendrical.Julian],
    cldr_calendar_type: :gregorian,
    weeks: [first_day: 1, min_days_in_first_week: 1]

  @impl Calendar
  def leap_year?(year), do: rem(year, 4) == 0

  @impl Calendar
  def days_in_month(year, 2), do: if(leap_year?(year), do: 29, else: 28)
  def days_in_month(_year, month) when month in [4, 6, 9, 11], do: 30
  def days_in_month(_year, _month), do: 31

  @impl true
  def date_to_iso_days(year, month, day), do: Calendrical.Julian.date_to_iso_days(year, month, day)

  @impl true
  def date_from_iso_days(iso_days), do: Calendrical.Julian.date_from_iso_days(iso_days)
end
```

The options are the facts of `info/0`:

* `:epoch` (required) — the first day of year 1, as a date in a calendar that has already been compiled.

* `:cldr_calendar_type` — the CLDR calendar whose data names the months, days and eras, `:gregorian` by default.

* `:era_calendar_type` — the CLDR calendar whose eras the calendar counts years in, the CLDR calendar type by default.

* `:months_in_year` — the number of months in a year, or `{fewest, most}` where a leap year has more, as the Hebrew calendar's `{12, 13}`. The default is `12`.

* `:weeks` — the rule the calendar's own weeks follow: `[first_day: 7, min_days_in_first_week: 1]`, with the first day numbered 1 for Monday to 7 for Sunday, or `:from_first_day` for weeks counted from the first day of the year. The default is Monday and 1.

* `:year_zero?` — whether the calendar has a year 0, `true` by default.

* `:year_cycle` — the cycle the years run in, as the sexagenary cycle of 60.

* `:years_in_cycle` — the number of years after which the calendar's days and weekdays repeat, where they do.

* `:location` — the place an astronomical calendar is reckoned at, a function of the ISO day number.

* `:month_lengths` — the lengths a month can have, by month, where the calendar states them rather than having them sampled.

* `:parsing_calendar` — the calendar a written date is parsed in, the calendar itself by default.

`months_in_year/1`, `valid_date?/3`, `year_of_era/3`, `day_of_era/3`, `shift/6` and `diff/3` have defaults the calendar may replace, and `leap_month/1`, `written_date/3` and `date_from_written_date/3` default to no leap month and a date written as its own fields. An option the maker does not read, and a definition of any other generated function, is refused at compile time.

## `use Calendrical.Calendar.Shifted`: a year begun elsewhere

A fiscal year, or a year counted from Lady Day as the Old Style did, is a base calendar's year cut at another day. Its date is a counted month and a day of it, so a year begun within a base month has a short month 1 and a short last month.

```elixir
defmodule MyApp.FiscalFromJuly do
  use Calendrical.Calendar.Shifted, year_begins: {7, 1}, year_number: :ending
end

defmodule MyApp.LadyDay do
  use Calendrical.Calendar.Shifted,
    base: Calendrical.Julian,
    year_begins: {3, 25},
    year_number: :beginning,
    written_year: :label
end
```

* `:base` — the calendar of months the year is cut from, `Calendrical.Gregorian` by default.

* `:year_begins` — `{month, day}` of the base calendar the year begins on.

* `:year_number` — the base year the year takes its number from, `:beginning`, `:ending` or `:majority`, the default.

* `:written_year` — the year a date is written with, `:base` by default, as a fiscal date is written with the Gregorian year, or `:label`, the calendar's own.

* `:weeks`, `:cldr_calendar_type`, `:era_calendar_type`, `:parsing_calendar` and `:years_in_cycle` as above, the facts defaulting to the base calendar's.

The kernel falls out of the base: a date is the base's date relabelled, a month's length the base month's, and `shift/6` the base's arithmetic on the base date. `base_date/3` and `date_from_base_date/3` convert either way. `Calendrical.new(module, :month, options)` makes one at runtime, and `Calendrical.FiscalYear.calendar_for/1` makes the fiscal year of a territory.

## `use Calendrical.Calendar.Weeks`: a year of whole weeks

A retail or fiscal calendar of 52 or 53 whole weeks, cut into twelve months of four or five weeks by a pattern. Its date is a month of the pattern and a day of it, so a month of four weeks has days 1 to 28.

```elixir
defmodule MyApp.Retail do
  use Calendrical.Calendar.Weeks,
    pattern: [4, 5, 4],
    year_ends: {:saturday, :nearest, {1, 31}}
end

defmodule MyApp.WeekYear do
  use Calendrical.Calendar.Weeks, year_begins: {:monday, :on_or_before, {1, 4}}
end
```

* `:pattern` — the weeks in the three months of a quarter, `[4, 4, 5]`, `[4, 5, 4]` or `[5, 4, 4]`; the default is `[4, 5, 4]`.

* `:year_begins` — `{weekday, :on_or_before, {month, day}}`, the weekday on or before a day of a Gregorian month, the day being 1 to 7; the ISO week year begins `{:monday, :on_or_before, {1, 4}}`. The default is `{:monday, :on_or_before, {1, 1}}`.

* `:year_ends` — instead of `:year_begins`: `{weekday, :on_or_after, {month, day}}`, the weekday on or after a day within the last seven of a Gregorian month, or `{weekday, :nearest, {month, last_day}}`.

* `:year_number` — the Gregorian year the year takes its number from, `:majority` by default.

* `:cldr_calendar_type` — the CLDR calendar that names the months, `:gregorian` by default.

`Calendrical.new(module, :week, options)` makes one at runtime.

## `use Calendrical.Calendar.Lunisolar`: a calendar reckoned from the sky

The Chinese calendar and its relations: a year of twelve or thirteen lunar months beginning at the second new moon after the winter solstice, with the leap month placed by the solar terms.

```elixir
defmodule MyApp.Chinese do
  use Calendrical.Calendar.Lunisolar,
    epoch: ~D[-2636-02-15],
    location: &__MODULE__.location/1

  def location(_iso_days), do: {39.9, 116.4, 44, 8 / 24}
end
```

* `:epoch` — the first day of year 1.

* `:location` — the place the calendar is reckoned at, a function of the ISO day number giving `{latitude, longitude, altitude, offset}` as `Astro` takes them.

* `:cldr_calendar_type` and `:era_calendar_type` — the naming facts, `:chinese` by default.

The maker supplies the whole kernel from `Calendrical.Lunisolar`, and `new/3`, `new!/3`, `leap_month?/2`, `gregorian_date_for_lunar/3` and `new_year_for_gregorian_year/1` beside it. A module keeps its own extras, as the festivals.

## `use Calendrical.Composite`: calendars in sequence

A calendar that uses one calendar until a day and another from it, as England did at the reform of 1752. See the [composite calendars guide](https://hexdocs.pm/calendrical/composite_calendars.html).

## What a calendar answers

Beyond `Calendar`'s own callbacks, every calendar module answers the derived questions by delegation: `info/0` and the naming facts (`cldr_calendar_type/0`, `era_calendar_type/0`, `parsing_calendar/0`, `parsing_calendars/0`), the months (`month_of_year/3`, `cldr_month/2`, `written_month_from_cldr_month/2`, `traditional_months/1`, `month_numbers/1`, `day_numbers/2`, `days_in_month/1`, `named_month/2`), the weeks (`week_of_year/3`, `iso_week_of_year/3`, `week_of_month/3`, `weeks_in_year/1`, `week/2`, `weeks_of_month/2`, `date_from_week_date/3`, `week_date_from_date/3`, `weeks_in_week_year/1`, `day_of_week/4`), the periods (`year/1`, `quarter/2`, `quadrimester/2`, `semester/2`, `month/2`, `quarter_of_year/3`, `day_of_year/3`, `days_in_year/1`, `date_from_day_of_year/2`, `dates_in_gregorian_year/3`), the years (`year_of_era/1`, `extended_year/3`, `related_gregorian_year/3`, `cyclic_year/3`, `years_in_cycle/0`) and the figures (`numeric_month/3`, `cardinal_day/3`, `cardinal_year/3`). Each is a one-line delegation to the derived API, generated once for every calendar, and none may be redefined.
