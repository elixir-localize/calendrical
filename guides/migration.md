# Migrating from ex_cldr_calendars to Calendrical

This guide covers the changes needed when migrating from [ex_cldr_calendars](https://hex.pm/packages/ex_cldr_calendars) (and its companion calendar libraries) to Calendrical.

## Overview

Calendrical consolidates the following ex_cldr packages into a single library:

| Old Package | New Module |
|---|---|
| `ex_cldr_calendars` (core) | `Calendrical` |
| `ex_cldr_calendars_persian` | `Calendrical.Persian` |
| `ex_cldr_calendars_coptic` | `Calendrical.Coptic` |
| `ex_cldr_calendars_ethiopic` | `Calendrical.Ethiopic` |
| `ex_cldr_calendars_japanese` | `Calendrical.Japanese` |
| `ex_cldr_calendars_lunisolar` | `Calendrical.Chinese`, `Calendrical.Korean`, `Calendrical.LunarJapanese` |
| `ex_cldr_calendars_format` | `Calendrical.Format`, `Calendrical.Formatter` |

All calendar functionality, localization data, formatting, and date arithmetic are available from a single dependency.

## Dependency changes

Remove all ex_cldr calendar dependencies and replace with `calendrical`:

```elixir
# Old
defp deps do
  [
    {:ex_cldr_calendars, "~> 2.0"},
    {:ex_cldr_calendars_persian, "~> 1.0"},
    {:ex_cldr_calendars_coptic, "~> 1.0"},
    {:ex_cldr_calendars_format, "~> 1.0"},
    # ... other calendar packages
  ]
end

# New
defp deps do
  [
    {:calendrical, "~> 0.1"},
  ]
end
```

Calendrical depends on [Localize](https://hex.pm/packages/localize) for CLDR locale data and [Astro](https://hex.pm/packages/astro) for astronomical calculations used by the Persian and lunisolar calendars.

## Localize replaces ex_cldr

Calendrical uses [Localize](https://hex.pm/packages/localize) instead of `ex_cldr` for all locale data access. Localize provides the same CLDR data but without the backend module architecture.

### No backend modules

The most significant architectural change is the removal of the backend pattern. There is no equivalent of `MyApp.Cldr` in Calendrical.

```elixir
# Old — required a backend module
defmodule MyApp.Cldr do
  use Cldr,
    providers: [Cldr.Calendar, Cldr.Number, Cldr.Unit, Cldr.List],
    locales: ["en", "fr", "ar", "he"],
    default_locale: "en"
end

MyApp.Cldr.Calendar.localize(date, :month)
MyApp.Cldr.Calendar.strftime_options!(locale: "fr")

# New — call Calendrical directly
Calendrical.localize(date, :month)
Calendrical.strftime_options!(locale: "fr")
```

### Locale management

Replace `Cldr` locale functions with their `Localize` equivalents:

| Old | New |
|---|---|
| `Cldr.get_locale()` | `Localize.get_locale()` |
| `Cldr.put_locale(locale)` | `Localize.put_locale(locale)` |
| `Cldr.validate_locale(locale, backend)` | `Localize.validate_locale(locale)` |
| `Cldr.validate_territory(territory)` | `Localize.validate_territory(territory)` |
| `Cldr.LanguageTag` | `Localize.LanguageTag` |
| `Cldr.Locale.territory_from_locale(locale)` | `Localize.Territory.territory_from_locale(locale)` |

All functions that previously accepted a `:backend` option no longer do. The `:locale` option defaults to `Localize.get_locale()`.

## Module namespace changes

All modules move from the `Cldr.Calendar` namespace to `Calendrical`:

| Old | New |
|---|---|
| `Cldr.Calendar` | `Calendrical` |
| `Cldr.Calendar.Gregorian` | `Calendrical.Gregorian` |
| `Cldr.Calendar.Julian` | `Calendrical.Julian` |
| `Cldr.Calendar.ISO` | `Calendrical.ISO` |
| `Cldr.Calendar.ISOWeek` | `Calendrical.ISOWeek` |
| `Cldr.Calendar.NRF` | `Calendrical.NRF` |
| `Cldr.Calendar.Persian` | `Calendrical.Persian` |
| `Cldr.Calendar.Coptic` | `Calendrical.Coptic` |
| `Cldr.Calendar.Ethiopic` | `Calendrical.Ethiopic` |
| `Cldr.Calendar.Japanese` | `Calendrical.Japanese` |
| `Cldr.Calendar.Chinese` | `Calendrical.Chinese` |
| `Cldr.Calendar.Korean` | `Calendrical.Korean` |
| `Cldr.Calendar.LunarJapanese` | `Calendrical.LunarJapanese` |
| `Cldr.Calendar.FiscalYear` | `Calendrical.FiscalYear` |
| `Cldr.Calendar.FiscalYear.US` | `Calendrical.FiscalYear.US` |
| `Cldr.Calendar.Config` | `Calendrical.Config` |
| `Cldr.Calendar.Interval` | `Calendrical.Interval` |
| `Cldr.Calendar.Kday` | `Calendrical.Kday` |
| `Cldr.Calendar.Sigils` | `Calendrical.Sigils` |
| `Cldr.Calendar.Preference` | `Calendrical.Preference` |

Territory-derived calendars also change namespace. For example, `Cldr.Calendar.US` becomes `Calendrical.US` and `Cldr.Calendar.GB` becomes `Calendrical.GB`.

### Exception modules

| Old | New |
|---|---|
| `Cldr.IncompatibleCalendarError` | `Calendrical.IncompatibleCalendarError` |
| `Cldr.InvalidCalendarModule` | `Calendrical.InvalidCalendarModule` |
| `Cldr.InvalidDateOrder` | `Calendrical.InvalidDateOrder` |
| `Cldr.IncompatibleTimeZone` | `Calendrical.IncompatibleTimeZone` |
| `Cldr.MissingFields` | `Calendrical.MissingFields` |

Some error functions now return Localize exception structs instead of `{ExceptionModule, message}` tuples. For example, `Localize.UnknownTerritoryError` is returned as `%Localize.UnknownTerritoryError{}` rather than `{Cldr.UnknownTerritoryError, "message"}`.

### Behaviour module

Calendars that use the behaviour macro change from `use Cldr.Calendar.Behaviour` to `use Calendrical.Behaviour`, and from `use Cldr.Calendar.Base.Month` / `use Cldr.Calendar.Base.Week` to `use Calendrical.Base.Month` / `use Calendrical.Base.Week`. The configuration options remain the same.

## Removed: Cldr.Calendar.Duration

The `Cldr.Calendar.Duration` module has been removed entirely. Use Elixir's built-in `%Duration{}` struct (available since Elixir 1.17) and `Date.diff/2` instead.

### Computing differences

```elixir
# Old
{:ok, duration} = Cldr.Calendar.Duration.new(~D[2020-01-01], ~D[2021-03-15])
# => {:ok, %Cldr.Calendar.Duration{year: 1, month: 2, day: 14, ...}}

# New — use Date.diff for day counts
Date.diff(~D[2021-03-15], ~D[2020-01-01])
# => 439

# Or construct a Duration directly
%Duration{year: 1, month: 2, day: 14}
```

### Formatting durations

The localized `Duration.to_string/2` function which used `Cldr.Unit` and `Cldr.List` for formatting has been removed. Use `Localize.Unit` and `Localize.List` directly if localized duration formatting is needed.

### Shifting dates with durations

```elixir
# Old
duration = Cldr.Calendar.Duration.new!(~D[2020-01-01], ~D[2020-03-15])
Cldr.Calendar.plus(~D[2025-01-01], duration)

# New — use Date.shift with a Duration
Date.shift(~D[2025-01-01], %Duration{month: 2, day: 14})
```

## Removed: Calendrical.plus and Calendrical.minus

The public `Calendrical.plus/2,3,4` and `Calendrical.minus/3,4` functions have been removed. Use Elixir's `Date.shift/2`, `DateTime.shift/2`, and `NaiveDateTime.shift/2` instead.

### Date arithmetic

```elixir
# Old
Cldr.Calendar.plus(date, :years, 1)
Cldr.Calendar.plus(date, :months, 3)
Cldr.Calendar.plus(date, :quarters, 1)
Cldr.Calendar.plus(date, :weeks, 2)
Cldr.Calendar.plus(date, :days, 10)
Cldr.Calendar.minus(date, :months, 1)

# New
Date.shift(date, year: 1)
Date.shift(date, month: 3)
Date.shift(date, month: 3)    # quarters: multiply by 3
Date.shift(date, week: 2)
Date.shift(date, day: 10)
Date.shift(date, month: -1)
```

`Date.shift/2` works correctly with all Calendrical calendar types including week-based fiscal calendars, lunisolar calendars, and the Julian calendar. Each calendar implements the `Calendar.shift_date/4` callback with the appropriate semantics for its calendar system.

### Coercion

The old `plus/4` accepted a `:coerce` option that controlled whether invalid dates (such as February 30) would be clamped to valid dates or return `{:error, :invalid_date}`. `Date.shift/2` always coerces to valid dates, matching the `coerce: true` default behaviour.

```elixir
# Old — could disable coercion
Cldr.Calendar.plus(~D[2024-01-31], :months, 1, coerce: false)
# => {:error, :invalid_date}

# New — always coerces
Date.shift(~D[2024-01-31], month: 1)
# => ~D[2024-02-29]
```

### No quarter unit

`Date.shift/2` does not support a `:quarter` unit. Multiply by 3 months instead:

```elixir
# Old
Cldr.Calendar.plus(date, :quarters, 2)

# New
Date.shift(date, month: 6)
```

### Date.Range shifting

The old `Cldr.Calendar.plus/4` could shift a `Date.Range` and return a new range for the resulting period. This is no longer supported as a single operation. Use `Calendrical.next/2` or `Calendrical.previous/2` for period navigation, which return `Date.Range` values for range inputs.

## Retained public API

The following functions continue to work as before (with namespace changes):

### Navigation

`Calendrical.next/2,3` and `Calendrical.previous/2,3` work as before but now use `Date.shift` internally. They accept dates and date ranges and return the next or previous period:

```elixir
Calendrical.next(~D[2024-03-15], :month)
# => ~D[2024-04-15]

Calendrical.previous(~D[2024-03-15], :year)
# => ~D[2023-03-15]

# With Date.Range inputs, returns the next/previous period as a range
year_range = Calendrical.Gregorian.year(2024)
Calendrical.next(year_range, :year)
# => Date.range(~D[2025-01-01], ~D[2025-12-31])
```

### Localization

`Calendrical.localize/2,3` works the same way but is called directly on the `Calendrical` module instead of through a backend:

```elixir
Calendrical.localize(~D[2024-06-15], :month)
# => "Jun"

Calendrical.localize(~D[2024-06-15], :month, format: :wide, locale: "fr")
# => "juin"

Calendrical.localize(~D[2024-06-15], :day_of_week)
# => "Sat"

Calendrical.localize(%{hour: 14}, :am_pm)
# => "PM"
```

### Locale data access

The locale data functions that were on the backend (`MyApp.Cldr.Calendar.eras/2`, `.months/2`, etc.) are now on the `Calendrical` module:

```elixir
Calendrical.eras(:en, :gregorian)
Calendrical.months(:en, :gregorian)
Calendrical.days(:fr, :gregorian)
Calendrical.quarters(:en, :gregorian)
Calendrical.day_periods(:en, :gregorian)
Calendrical.cyclic_years(:en, :chinese)
Calendrical.month_patterns(:en, :chinese)
```

These return `{:ok, data}` tuples.

### Calendar creation

```elixir
# Creating custom calendars
{:ok, MyFiscal} = Calendrical.new(MyFiscal, :month, month_of_year: 7, year: :ending)

# Or using the behaviour directly in a module
defmodule MyApp.FiscalYear do
  use Calendrical.Base.Month,
    month_of_year: 7,
    year: :ending
end

# Week-based calendar
defmodule MyApp.Retail do
  use Calendrical.Base.Week,
    begins_or_ends: :ends,
    first_or_last: :last,
    day_of_week: 6,
    month_of_year: 1,
    weeks_in_month: [4, 4, 5]
end
```

### Intervals and streams

```elixir
Calendrical.interval(~D[2024-01-01], 6, :months)
# => [~D[2024-01-01], ~D[2024-02-01], ~D[2024-03-01], ...]

Calendrical.interval_stream(~D[2024-01-01], ~D[2024-12-31], :quarters)
|> Enum.to_list()
```

### Sigils

The `~d` sigil works the same way:

```elixir
import Calendrical.Sigils

~d[2024-06-15]                    # Gregorian
~d[2024-06-15 Gregorian]          # Explicit Gregorian
~d[2024-W24-6]                    # ISO Week
~d[2024-06-15 Persian]            # Persian calendar
~d[1446-06-15 C.E. Julian]        # Julian calendar
```

## Calendar formatting (ex_cldr_calendars_format)

The `ex_cldr_calendars_format` library is now part of Calendrical. It provides a behaviour-based plugin system for rendering calendars as HTML, Markdown, or custom formats.

### Module renames

| Old | New |
|---|---|
| `Cldr.Calendar.Format` | `Calendrical.Format` |
| `Cldr.Calendar.Formatter` | `Calendrical.Formatter` |
| `Cldr.Calendar.Formatter.Options` | `Calendrical.Formatter.Options` |
| `Cldr.Calendar.Formatter.HTML.Basic` | `Calendrical.Formatter.HTML.Basic` |
| `Cldr.Calendar.Formatter.HTML.Week` | `Calendrical.Formatter.HTML.Week` |
| `Cldr.Calendar.Formatter.Markdown` | `Calendrical.Formatter.Markdown` |
| `Cldr.Calendar.Formatter.UnknownFormatterError` | `Calendrical.Formatter.UnknownFormatterError` |
| `Cldr.Calendar.Formatter.InvalidDateError` | `Calendrical.Formatter.InvalidDateError` |
| `Cldr.Calendar.Formatter.InvalidOption` | `Calendrical.Formatter.InvalidOption` |

### Removed `:backend` option

The `:backend` option has been removed from `Calendrical.Formatter.Options`. If passed, it is silently ignored for backward compatibility.

```elixir
# Old
Cldr.Calendar.Format.year(2024, backend: MyApp.Cldr, locale: "fr")
Cldr.Calendar.Format.month(2024, 6, backend: MyApp.Cldr, formatter: Cldr.Calendar.Formatter.Markdown)

# New
Calendrical.Format.year(2024, locale: "fr")
Calendrical.Format.month(2024, 6, formatter: Calendrical.Formatter.Markdown)
```

The `:locale` option defaults to `Localize.get_locale()` instead of `backend.get_locale()`.

### Number formatting changes

The formatter options validation for `:number_system` now uses the Localize API directly. The old three-argument `Cldr.Number.validate_number_system(locale, system, backend)` is replaced by `Localize.validate_number_system(system)`.

Number formatting inside formatters uses `Localize.Number.to_string!/2` instead of `Cldr.Number.to_string!/3` (no backend parameter):

```elixir
# Old (inside a custom formatter)
Cldr.Number.to_string!(day, backend, locale: locale, number_system: number_system)

# New
Localize.Number.to_string!(day, locale: locale, number_system: number_system)
```

### Custom formatter behaviour

The `Calendrical.Formatter` behaviour callbacks are unchanged. Custom formatters that implement the four callbacks (`format_year/3`, `format_month/4`, `format_week/5`, `format_day/4`) work the same way. The only change is the module name in the `@behaviour` declaration and the `Options` struct no longer containing a `:backend` field:

```elixir
# Old
defmodule MyApp.CustomFormatter do
  @behaviour Cldr.Calendar.Formatter

  @impl true
  def format_day(date, year, month, options) do
    # options.backend was available here
    ...
  end
end

# New
defmodule MyApp.CustomFormatter do
  @behaviour Calendrical.Formatter

  @impl true
  def format_day(date, year, month, options) do
    # options.backend no longer exists
    # use Localize directly for any locale data needs
    ...
  end
end
```

### Options struct changes

The `Calendrical.Formatter.Options` struct fields:

| Field | Status | Notes |
|---|---|---|
| `:calendar` | Unchanged | Calendar module, defaults to `Calendrical.Gregorian` |
| `:formatter` | Unchanged | Formatter module, defaults to `Calendrical.Formatter.HTML.Basic` |
| `:locale` | Changed | Defaults to `Localize.get_locale()` instead of `backend.get_locale()` |
| `:number_system` | Changed | Validated via `Localize.validate_number_system/1` |
| `:territory` | Changed | Derived via `Localize.Territory.territory_from_locale/1` |
| `:backend` | **Removed** | No longer present in the struct |
| `:caption` | Unchanged | |
| `:class` | Unchanged | |
| `:id` | Unchanged | |
| `:today` | Unchanged | |
| `:day_names` | Unchanged | |
| `:private` | Unchanged | |

## Configuration changes

The `Calendrical.Config` struct no longer includes a `:cldr_backend` field. The `:locale` option can be used when creating calendars to derive locale-specific defaults for `:day_of_week` and `:min_days_in_first_week`.

```elixir
# Old
Cldr.Calendar.new(MyCalendar, :week, [
  cldr_backend: MyApp.Cldr,
  day_of_week: 1,
  month_of_year: 1
])

# New
Calendrical.new(MyCalendar, :week, [
  day_of_week: 1,
  month_of_year: 1
])
```

## Unit application order

A subtle but important semantic difference: `Date.shift/2` applies duration units in order from largest to smallest (years → months → weeks → days), matching the Elixir stdlib convention. The old `Cldr.Calendar.plus(date, %Duration{})` applied units in the opposite order (days → months → years). In most cases the results are identical, but they can differ when date clamping occurs at intermediate steps.
