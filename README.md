# Calendrical

Localized month- and week-based calendars, fiscal-year support, calendar arithmetic, and 17+ CLDR-based calendar systems for Elixir, built on the [Unicode CLDR](https://cldr.unicode.org/) repository via [Localize](https://hex.pm/packages/localize).

Calendrical extends Elixir's standard `Calendar` and `Date` modules with comprehensive support for the calendar systems used around the world, including arithmetic and astronomical lunar calendars, year-shifted variants such as Buddhist and ROC, and the official tabular and observational Islamic calendars.

## Features

* **17 CLDR-aligned calendar implementations** — Gregorian, Persian, Coptic, Ethiopic (two eras), Japanese, Chinese, Korean (Dangi), Lunar Japanese, four Islamic variants (Civil, TBLA, Umm al-Qura, observational), Hebrew, Buddhist, Republic of China (Minguo), Indian National (Saka), and Julian.

* **`Calendrical.Behaviour`** — a `defmacro __using__` template that supplies default implementations of every `Calendar` and `Calendrical` callback. Users can define a new calendar in 60–200 lines by overriding only the parts that differ from the defaults.

* **Composite calendars** — `Calendrical.Composite` lets you build a calendar that uses one base calendar before a specified date and another after, supporting historical Julian-to-Gregorian transitions and similar splices.

* **Localized formatting** — era names, quarter names, month names, day names, day periods (AM/PM), and full date formatting via `Calendrical.localize/3` and `Calendrical.strftime_options!/1`. Falls through to all 766+ CLDR locales available from `Localize`.

* **Fiscal-year calendars** — pre-built fiscal calendars for ~50 territories (US, UK, AU, JP, …) plus a configurable `Calendrical.FiscalYear.calendar_for/1` factory.

* **Date arithmetic** — `Calendrical.shift_date/4`, `Calendrical.shift_naive_datetime/8`, and the standard `Date.shift/2` work across every calendar.

* **Date intervals** — `Calendrical.Interval` returns `Date.Range` values for years, quarters, months, weeks, and days in any supported calendar, with `relation/2` implementing Allen's interval algebra.

* **k-day calculations** — `Calendrical.Kday` finds the *n*-th occurrence of a given weekday relative to a date (e.g. "the second Tuesday in November").

* **Calendar formatters** — `Calendrical.Format` and `Calendrical.Formatter` provide a behaviour-based plugin system for rendering calendars as HTML, Markdown, or any custom format.

* **Astronomical calendar support** — observational lunar calendars (Persian, Chinese, Korean, Lunar Japanese, observational Islamic, Saudi Rgsa, astronomical Umm al-Qura) use the [Astro](https://hex.pm/packages/astro) library for equinox, lunar phase, and crescent visibility calculations.

* **Sigils** — `~d` literals for any registered calendar (`~d[2024-09-01 Calendrical.Hebrew]`, `~d[1446-09-01 Calendrical.Islamic.UmmAlQura]`).

* **Ecclesiastical calendars** — `Calendrical.Ecclesiastical` provides Reingold-style algorithms for the movable and fixed Christian feasts of three different traditions: **Western** (`easter_sunday/1`, `good_friday/1`, `pentecost/1`, `advent/1`, `christmas/1`, `epiphany/1`), **Eastern Orthodox** (`orthodox_easter_sunday/1`, `orthodox_good_friday/1`, `orthodox_pentecost/1`, `orthodox_advent/1`, `eastern_orthodox_christmas/1`), and **astronomical** (`astronomical_easter_sunday/1`, `astronomical_good_friday/1`, `paschal_full_moon/1` — the WCC 1997 proposed reckoning).

## Supported Elixir and OTP versions

Calendrical requires **Elixir 1.17+** and **Erlang/OTP 26+**.

## Installation

Add `calendrical` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:calendrical, "~> 0.1.0"}
  ]
end
```

## Quick start

```elixir
iex> # Convert a Gregorian date to the Hebrew calendar
iex> {:ok, gregorian} = Date.new(2024, 10, 3, Calendrical.Gregorian)
iex> {:ok, hebrew} = Date.convert(gregorian, Calendrical.Hebrew)
iex> hebrew
~D[5785-01-01 Calendrical.Hebrew]

iex> # Localize the month name
iex> Calendrical.localize(hebrew, :month, locale: "en")
"Tishri"

iex> Calendrical.localize(hebrew, :month, locale: "he", format: :wide)
"תשרי"

iex> # Convert to the Islamic Umm al-Qura calendar
iex> {:ok, hijri} = Date.convert(gregorian, Calendrical.Islamic.UmmAlQura)
iex> Calendrical.localize(hijri, :month, locale: "en")
"Rabiʻ I"

iex> # Buddhist Era (Thailand)
iex> {:ok, buddhist} = Date.convert(gregorian, Calendrical.Buddhist)
iex> buddhist.year
2567

iex> # Get a date range for a fiscal year quarter
iex> {:ok, calendar} = Calendrical.FiscalYear.calendar_for(:US)
iex> Calendrical.Interval.quarter(2024, 1, calendar)

iex> # Find the second Tuesday in November 2024
iex> Calendrical.Kday.nth_kday(~D[2024-11-01], 2, :tuesday)
~D[2024-11-12]

iex> # Western Easter Sunday for 2024 (Gregorian computus)
iex> Calendrical.Ecclesiastical.easter_sunday(2024)
~D[2024-03-31 Calendrical.Gregorian]

iex> # Eastern Orthodox Easter Sunday for 2024 (Julian computus)
iex> Calendrical.Ecclesiastical.orthodox_easter_sunday(2024)
~D[2024-04-22 Calendrical.Julian]

iex> # Astronomical Paschal Full Moon for 2025
iex> {:ok, pfm} = Calendrical.Ecclesiastical.paschal_full_moon(2025)
iex> pfm
~D[2025-04-13]
```

## Available calendars

Calendrical implements all 17 calendar systems exposed by CLDR. They are grouped below by their underlying mechanism. See [`guides/calendar_summary.md`](guides/calendar_summary.md) for the full descriptions, eras, month structures, and reference dates.

| Family | Calendars |
|---|---|
| **Gregorian-based** (year-offset over `Calendrical.Gregorian`) | `Calendrical.Gregorian`, `Calendrical.ISO`, `Calendrical.ISOWeek`, `Calendrical.NRF`, `Calendrical.Buddhist`, `Calendrical.Roc`, `Calendrical.Japanese`, `Calendrical.Indian` |
| **Julian-based** (proleptic Julian + variants) | `Calendrical.Julian`, `Calendrical.Julian.Jan1`, `Calendrical.Julian.March1`, `Calendrical.Julian.March25`, `Calendrical.Julian.Sept1`, `Calendrical.Julian.Dec25` |
| **Solar (non-Gregorian)** | `Calendrical.Persian` (astronomical) |
| **Lunar (tabular)** | `Calendrical.Coptic`, `Calendrical.Ethiopic`, `Calendrical.Ethiopic.AmeteAlem`, `Calendrical.Islamic.Civil`, `Calendrical.Islamic.Tbla`, `Calendrical.Islamic.UmmAlQura` |
| **Lunar (observational/astronomical)** | `Calendrical.Islamic.Observational` (Cairo), `Calendrical.Islamic.Rgsa` (Mecca), `Calendrical.Islamic.UmmAlQura.Astronomical` |
| **Lunisolar** | `Calendrical.Hebrew` (arithmetic), `Calendrical.Chinese`, `Calendrical.Korean` (Dangi), `Calendrical.LunarJapanese` |
| **Composite** | `Calendrical.Composite` (user-defined; e.g. England with Julian-to-Gregorian transition) |
| **Fiscal-year** | `Calendrical.FiscalYear.US`, `.AU`, `.UK`, … (50+ territories) |

## Defining your own calendar

Calendrical exposes the same `Calendrical.Behaviour` macro that the built-in calendars use. A custom calendar typically needs to define its own `date_to_iso_days/3` and `date_from_iso_days/1`, plus override one or two callbacks (`leap_year?/1`, `days_in_month/2`, etc.) when its rules differ from the defaults.

```elixir
defmodule MyApp.MyCalendar do
  use Calendrical.Behaviour,
    epoch: ~D[0001-01-01 Calendar.ISO],
    cldr_calendar_type: :gregorian

  @impl true
  def leap_year?(year), do: rem(year, 4) == 0

  def date_to_iso_days(year, month, day) do
    # ... calendar-specific calculation
  end

  def date_from_iso_days(iso_days) do
    # ... calendar-specific calculation
  end
end
```

See [`guides/calendar_behaviour.md`](guides/calendar_behaviour.md) for the full list of options, generated functions, and overridable callbacks.

## Localization

All calendars participate in CLDR localization automatically. Calling `Calendrical.localize/3` with a date and a part (`:era`, `:month`, `:quarter`, `:day_of_week`, `:days_of_week`, `:am_pm`, `:day_periods`) returns the locale-specific name through the `Localize.Calendar` data layer.

```elixir
iex> {:ok, date} = Date.new(1446, 9, 1, Calendrical.Islamic.UmmAlQura)
iex> Calendrical.localize(date, :month, locale: "en")
"Ramadan"

iex> Calendrical.localize(date, :month, locale: "ar")
"رمضان"

iex> Calendrical.localize(date, :day_of_week, locale: "en", format: :wide)
"Saturday"
```

`Calendrical.strftime_options!/1` returns a keyword list compatible with `Calendar.strftime/3` so the standard library's formatter can produce locale-aware output for any Calendrical calendar.

## Composite calendars

A composite calendar uses one base calendar before a specified transition date and another afterwards. The canonical example is the European transition from the Julian to the Gregorian calendar in the 16th–20th centuries.

```elixir
defmodule MyApp.England do
  use Calendrical.Composite,
    calendars: [
      ~D[1155-03-25 Calendrical.Julian.March25],
      ~D[1751-03-25 Calendrical.Julian.Jan1],
      ~D[1752-09-14 Calendrical.Gregorian]
    ],
    base_calendar: Calendrical.Julian
end

# 11 days are "missing" at the September 1752 transition
iex> Date.shift(~D[1752-09-02 MyApp.England], day: 1)
~D[1752-09-14 MyApp.England]
```

A composite calendar can chain any number of transitions and combine any pair of calendars. See `Calendrical.Composite` for details.

## Configuration

Calendrical inherits the locale and provider configuration from `Localize`. The only Calendrical-specific configuration is for the few lunisolar calendars that accept a custom epoch:

```elixir
config :calendrical,
  chinese_epoch: ~D[-2636-02-15],
  korean_epoch: ~D[-2332-02-15],
  lunar_japanese_epoch: ~D[0645-07-20]
```

| Option | Default | Description |
|---|---|---|
| `:chinese_epoch` | `~D[-2636-02-15]` | The first sexagesimal cycle origin used by the Chinese calendar. |
| `:korean_epoch` | `~D[-2332-02-15]` | The founding-of-Korea origin used by the Korean (Dangi) calendar. |
| `:lunar_japanese_epoch` | `~D[0645-07-20]` | The Taika-era origin used by the Lunar Japanese calendar. |

For Calendrical's underlying locale, default-locale, and locale-cache configuration, see the [Localize configuration documentation](https://hexdocs.pm/localize).

## Documentation

* [`guides/calendar_summary.md`](guides/calendar_summary.md) — every supported calendar grouped by family, with month structure, era information, leap-year rules, and reference dates.

* [`guides/calendar_behaviour.md`](guides/calendar_behaviour.md) — how to define your own calendar by `use`ing `Calendrical.Behaviour`, including every option, every overridable callback, and worked examples.

* [`guides/migration.md`](guides/migration.md) — migrating from `ex_cldr_calendars` and the related `cldr_calendars_*` libraries.

* [`CHANGELOG.md`](CHANGELOG.md) — release history.

Full API documentation is available on [HexDocs](https://hexdocs.pm/calendrical).

## License

Apache License 2.0. See the [LICENSE](LICENSE.md) file for details.
