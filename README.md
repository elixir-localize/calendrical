# Calendrical

Localized month- and week-based calendars, fiscal-year support, calendar arithmetic, and 21 calendar systems for Elixir, built on the [Unicode CLDR](https://cldr.unicode.org/) repository via [Localize](https://hex.pm/packages/localize). Calendrical 2.0 is built on Localize 1.4 and CLDR 49.

Calendrical extends Elixir's standard `Calendar` and `Date` modules with comprehensive support for the calendar systems used around the world, including arithmetic and astronomical lunar calendars, year-shifted variants such as Buddhist and ROC, and the official tabular and observational Islamic calendars.

## Features

* **21 calendar implementations** — Gregorian, Persian, Coptic, Ethiopic (two eras), Japanese, Chinese, Korean (Dangi), Lunar Japanese, Vietnamese, six Islamic variants (Civil, TBLA, tabular and astronomical Umm al-Qura, and the observational calendars of Cairo and Mecca), Hebrew, Buddhist, Republic of China (Minguo), Indian National (Saka), and Julian: every calendar CLDR defines, and more.

* **Five makers** — `use Calendrical.Calendar` for a hand-written calendar, `Calendrical.Calendar.Shifted` for a year begun elsewhere in a base calendar's year, `Calendrical.Calendar.Weeks` for a year of whole weeks, `Calendrical.Calendar.Lunisolar` for a calendar reckoned from the sky and `Calendrical.Composite` for calendars in sequence. Each implements a kernel of eight callbacks from its options, and every other answer is derived from the kernel, so a new calendar is its spine and a handful of facts.

* **Composite calendars** — `Calendrical.Composite` lets you build a calendar that uses one base calendar before a specified date and another after, supporting historical Julian-to-Gregorian transitions and similar splices.

* **Localized formatting** — era names, quarter names, month names, day names, day periods (AM/PM), and full date formatting via `Calendrical.localize/3` and `Calendrical.strftime/3`. Falls through to all 657 CLDR locales available from `Localize`.

* **Fiscal-year calendars** — `Calendrical.FiscalYear.calendar_for/1` builds the fiscal calendar of any of ~50 territories (US, GB, AU, JP, …) on first use, and `Calendrical.new/3` makes any other.

* **Date arithmetic** — the standard `Date.shift/2` and `NaiveDateTime.shift/2` work across every Calendrical calendar.

* **Date intervals** — `Calendrical.Interval` returns `Date.Range` values for years, quarters, months, weeks, and days in any supported calendar, with `relation/2` implementing Allen's interval algebra.

* **k-day calculations** — `Calendrical.Kday` finds the *n*-th occurrence of a given weekday relative to a date (e.g. "the second Tuesday in November").

* **Calendar formatters** — `Calendrical.Format` and `Calendrical.Formatter` provide a behaviour-based plugin system for rendering calendars as HTML, Markdown, or any custom format.

* **Astronomical calendar support** — observational lunar calendars (Persian, Chinese, Korean, Lunar Japanese, observational Islamic, Saudi Rgsa, astronomical Umm al-Qura) use the [Astro](https://hex.pm/packages/astro) library for equinox, lunar phase, and crescent visibility calculations. Astro ships a bundled ephemeris covering **1900–2100**, so these calendars work out of the box with no download step; `mix astro.download_ephemeris` installs the full **1849–2150** ephemeris when a wider range is needed.

* **Sigils** — every Calendrical calendar works with Elixir's native `~D`/`~U`/`~N` sigils via the standard calendar suffix: `~D[2024-09-01 Calendrical.Hebrew]`, `~D[1446-09-01 Calendrical.Islamic.UmmAlQura]`.

* **Ecclesiastical calendars** — `Calendrical.Ecclesiastical` provides Reingold-style algorithms for the movable and fixed Christian feasts of three different traditions: **Western** (`easter_sunday/1`, `good_friday/1`, `pentecost/1`, `advent/1`, `christmas/1`, `epiphany/1`), **Eastern Orthodox** (`orthodox_easter_sunday/1`, `orthodox_good_friday/1`, `orthodox_pentecost/1`, `orthodox_advent/1`, `eastern_orthodox_christmas/1`), and **astronomical** (`astronomical_easter_sunday/1`, `astronomical_good_friday/1`, `paschal_full_moon/1` — the WCC 1997 proposed reckoning).

## Supported Elixir and OTP versions

Calendrical requires **Elixir 1.17+** and **Erlang/OTP 26+**.

On OTP 26, also add `{:json_polyfill, "~> 0.2 or ~> 1.0"}` to your dependencies. It provides the OTP 27+ `:json` module that Localize uses. OTP 27 and later need no extra dependency.

## Installation

Add `calendrical` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:calendrical, "~> 2.2"}
  ]
end
```

Localize ships with the `en` locale. Download the data for any other locale your application uses at build time with `mix localize.download_locales`, for example `mix localize.download_locales fr ar he`. Without it, a call for another locale falls back to `en`. See [`mix localize.download_locales`](https://hexdocs.pm/localize/Mix.Tasks.Localize.DownloadLocales.html).

`Calendrical.TimeZone` resolves IANA time zone names through a `Calendar.TimeZoneDatabase`. Add one, such as [`tz`](https://hex.pm/packages/tz), which is used automatically once it is loaded, or configure one with `config :elixir, :time_zone_database, Tz.TimeZoneDatabase`. Without one, IANA names are rejected.

### Starting Calendrical in your own supervision tree

Calendrical starts with your application, under `Calendrical.Supervisor`. To start it in your own supervision tree instead, mark the dependency `runtime: false`, list the supervisors among your application's children, and name Calendrical in your release:

```elixir
# mix.exs
def project do
  [
    app: :my_app,
    deps: [{:calendrical, "~> 2.2", runtime: false}],
    releases: [my_app: [applications: [calendrical: :load]]]
  ]
end

# lib/my_app/application.ex
children = [
  Localize.Supervisor,
  Astro.Supervisor,
  Calendrical.Supervisor,
  MyApp.Worker
]
```

Astro must start before Calendrical, since it loads the JPL ephemeris the astronomical calendars compute from: list `Astro.Supervisor` before `Calendrical.Supervisor`, or leave it out and `Calendrical.Supervisor` starts the `:astro` application itself. List `Localize.Supervisor` before any process that formats or parses dates. The [supervision guide](https://hexdocs.pm/calendrical/supervision.html) describes the setup in full.

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

iex> Calendrical.localize(hebrew, :month, locale: "he", style: :wide)
"תשרי"

iex> # Convert to the Islamic Umm al-Qura calendar
iex> {:ok, hijri} = Date.convert(gregorian, Calendrical.Islamic.UmmAlQura)
iex> Calendrical.localize(hijri, :month, locale: "en")
"Rab. I"

iex> # Buddhist Era (Thailand)
iex> {:ok, buddhist} = Date.convert(gregorian, Calendrical.Buddhist)
iex> buddhist.year
2567

iex> # Get a date range for a fiscal year quarter. The US fiscal year
iex> # 2024 begins on 1 October 2023, which its calendar counts as month 1
iex> {:ok, calendar} = Calendrical.FiscalYear.calendar_for(:US)
iex> Calendrical.Interval.quarter(2024, 1, calendar)
Date.range(~D[2024-01-01 Calendrical.FiscalYear.US], ~D[2024-03-31 Calendrical.FiscalYear.US])

iex> # Find the second Tuesday in November 2024 (Tuesday = day 2)
iex> Calendrical.Kday.nth_kday(~D[2024-11-01], 2, 2)
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

Calendrical implements every calendar system exposed by CLDR, plus lunisolar variants observed from other meridians (Lunar Japanese and Vietnamese). They are grouped below by their underlying mechanism. See [`guides/calendar_summary.md`](https://hexdocs.pm/calendrical/calendar_summary.html) for the full descriptions, eras, month structures, and reference dates.

| Family | Calendars |
|---|---|
| **Gregorian-based** (Gregorian months, or whole weeks of them) | `Calendrical.Gregorian`, `Calendrical.ISO`, `Calendrical.ISOWeek`, `Calendrical.NRF`, `Calendrical.Buddhist`, `Calendrical.Roc`, `Calendrical.Japanese` |
| **Julian-based** (proleptic Julian + variants) | `Calendrical.Julian`, `Calendrical.Julian.Jan1`, `Calendrical.Julian.March1`, `Calendrical.Julian.March25`, `Calendrical.Julian.Sept1`, `Calendrical.Julian.Dec25` |
| **Solar (non-Gregorian)** | `Calendrical.Persian` (astronomical), `Calendrical.Indian`, `Calendrical.Coptic`, `Calendrical.Ethiopic`, `Calendrical.Ethiopic.AmeteAlem` |
| **Lunar (tabular)** | `Calendrical.Islamic.Civil`, `Calendrical.Islamic.Tbla`, `Calendrical.Islamic.UmmAlQura` |
| **Lunar (observational/astronomical)** | `Calendrical.Islamic.Observational` (Cairo), `Calendrical.Islamic.Rgsa` (Mecca), `Calendrical.Islamic.UmmAlQura.Astronomical` |
| **Lunisolar** | `Calendrical.Hebrew` (arithmetic), `Calendrical.Chinese`, `Calendrical.Korean` (Dangi), `Calendrical.LunarJapanese`, `Calendrical.Vietnamese` (Hanoi meridian) |
| **Composite** | `Calendrical.Composite` (user-defined; e.g. England with Julian-to-Gregorian transition) |
| **Fiscal-year** | `Calendrical.FiscalYear.US`, `.AU`, `.GB`, … (50+ territories, built by `Calendrical.FiscalYear.calendar_for/1`) |

## Defining your own calendar

A calendar is a kernel of eight callbacks and the facts its `info/0` states; everything else is derived. `use Calendrical.Calendar` makes a hand-written calendar from its spine, `date_to_iso_days/3` and `date_from_iso_days/1`, and the six primitive `Calendar` callbacks:

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

A year begun elsewhere in a base calendar's year, as a fiscal year is, needs no code at all: `use Calendrical.Calendar.Shifted, year_begins: {7, 1}`. A year of whole weeks is `use Calendrical.Calendar.Weeks, pattern: [4, 5, 4], year_ends: {:saturday, :nearest, {1, 31}}`, and `Calendrical.new/3` makes either at runtime.

See [`guides/calendar_behaviour.md`](https://hexdocs.pm/calendrical/calendar_behaviour.html) for the kernel, every option of the five makers, and what a calendar may override.

## Localization

All calendars participate in CLDR localization automatically. Calling `Calendrical.localize/3` with a date and a part (`:era`, `:month`, `:quarter`, `:day_of_week`, `:days_of_week`, `:day_period`, `:day_periods`) returns the locale-specific name through the `Localize.Calendar` data layer.

```elixir
iex> {:ok, date} = Date.new(1446, 9, 1, Calendrical.Islamic.UmmAlQura)
iex> Calendrical.localize(date, :month, locale: "en", style: :wide)
"Ramadan"

iex> Calendrical.localize(date, :month, locale: "ar")
"رمضان"

iex> Calendrical.localize(date, :day_of_week, locale: "en", style: :wide)
"Saturday"
```

`Calendrical.strftime/3` formats a date of any calendar with locale-aware names. `Calendrical.strftime_options!/1` returns options for the standard library's `Calendar.strftime/3`, which names a month by its month field, so it suits the Gregorian-based calendars; use `Calendrical.strftime/3` for the Hebrew, lunisolar, fiscal and week calendars.

## Composite calendars

A composite calendar uses one base calendar before a specified transition date and another afterwards. The canonical example is the European transition from the Julian to the Gregorian calendar in the 16th–20th centuries.

```elixir
defmodule MyApp.England do
  use Calendrical.Composite,
    calendars: [
      # 25 March 1155: the Lady Day calendar's month 1 day 1
      ~D[1155-01-01 Calendrical.Julian.March25],
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
  lunar_japanese_epoch: ~D[0645-02-05]
```

| Option | Default | Description |
|---|---|---|
| `:chinese_epoch` | `~D[-2636-02-15]` | The first sexagesimal cycle origin used by the Chinese calendar. |
| `:korean_epoch` | `~D[-2332-02-15]` | The founding-of-Korea origin used by the Korean (Dangi) calendar. |
| `:lunar_japanese_epoch` | `~D[0645-02-05]` | The lunar new year of the year the Taika era was proclaimed, the first day of year 1 of the Lunar Japanese calendar. |
| `:vietnamese_epoch` | `~D[-2636-02-15]` | The sexagesimal cycle origin used by the Vietnamese calendar (shared with the Chinese calendar). |

For Calendrical's underlying locale, default-locale, and locale-cache configuration, see the [Localize configuration documentation](https://hexdocs.pm/localize).

## Documentation

* [`guides/calendar_summary.md`](https://hexdocs.pm/calendrical/calendar_summary.html) — every supported calendar grouped by family, with month structure, era information, leap-year rules, and reference dates.

* [`guides/calendar_behaviour.md`](https://hexdocs.pm/calendrical/calendar_behaviour.html) — how to make your own calendar with the five makers: the kernel, every option, what may be overridden, and worked examples.

* [`guides/migration.md`](https://hexdocs.pm/calendrical/migration.html) — migrating from `ex_cldr_calendars` and the related `cldr_calendars_*` libraries.

* [`CHANGELOG.md`](https://hexdocs.pm/calendrical/changelog.html) — release history.

Full API documentation is available on [HexDocs](https://hexdocs.pm/calendrical).

## License

Apache License 2.0. See the [LICENSE](https://hexdocs.pm/calendrical/license.html) file for details. The Umm al-Qura month lengths for 1501 to 1600 AH are derived from ICU and are under the [Unicode License V3](https://hexdocs.pm/calendrical/license-unicode.html).

