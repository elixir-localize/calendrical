# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] — Unreleased

This is the first release of Calendrical, which consolidates the `ex_cldr_calendars` library family into a single package built on `Localize`. Functionality from the following libraries has been merged in: `ex_cldr_calendars`, `ex_cldr_calendars_persian`, `ex_cldr_calendars_coptic`, `ex_cldr_calendars_ethiopic`, `ex_cldr_calendars_japanese`, `ex_cldr_calendars_lunisolar`, `ex_cldr_calendars_islamic`, `ex_cldr_calendars_format`, and `ex_cldr_calendars_composite`.

### Added

* `Calendrical.Behaviour` — a `defmacro __using__` template that supplies sensible default implementations of every `Calendar` and `Calendrical` callback. Calendars `use` the behaviour, supply an `:epoch` (and any non-default options), define `date_to_iso_days/3` and `date_from_iso_days/1`, and override only the callbacks that differ from the defaults. Every generated function is `defoverridable`. See [`guides/calendar_behaviour.md`](guides/calendar_behaviour.md).

* All 17 CLDR-acceptable calendar types are implemented:

  * `Calendrical.Gregorian`, `Calendrical.ISO`, `Calendrical.ISOWeek`, `Calendrical.NRF` — month- and week-based Gregorian calendars.

  * `Calendrical.Julian` and the year-start variants `Calendrical.Julian.Jan1`, `Calendrical.Julian.March1`, `Calendrical.Julian.March25`, `Calendrical.Julian.Sept1`, `Calendrical.Julian.Dec25`.

  * `Calendrical.Buddhist` — Thai Buddhist Era (Gregorian + 543).

  * `Calendrical.Roc` — Republic of China / Minguo (Gregorian − 1911).

  * `Calendrical.Japanese` — proleptic Gregorian with Japanese era data for localization.

  * `Calendrical.Indian` — Indian National (Saka) calendar with custom 30/31-day month structure and Saka era (Gregorian − 78).

  * `Calendrical.Persian` — astronomical Persian calendar based on the vernal equinox at Tehran, computed via `Astro.equinox/2`.

  * `Calendrical.Coptic` and `Calendrical.Ethiopic` — 13-month tabular calendars sharing the `mod(year, 4) == 3` leap-year rule, with overridden `quarter_of_year/3`, `day_of_week/4`, and `valid_date?/3`.

  * `Calendrical.Ethiopic.AmeteAlem` — Ethiopic calendar with the *Era of the World* (Anno Mundi) year offset of +5500 over the standard *Era of Mercy*.

  * `Calendrical.Islamic.Civil` and `Calendrical.Islamic.Tbla` — tabular Hijri calendars with the Type II Kūshyār 30-year leap cycle. They share a private `Calendrical.Islamic.Tabular` helper and differ only in epoch (Friday 16 July 622 Julian vs Thursday 15 July 622 Julian).

  * `Calendrical.Islamic.UmmAlQura` — Saudi Umm al-Qura tabular calendar embedding the official KACST/van Gent first-of-month dataset (1356–1500 AH) at compile time. Conversions are O(1) forward and O(log n) reverse via binary search.

  * `Calendrical.Islamic.UmmAlQura.Astronomical` — Astronomical implementation of the Umm al-Qura rule using the `Astro` library's sunset/moonset and lunar phase functions for Mecca. Available for research and validation against the embedded table.

  * `Calendrical.Islamic.Observational` and `Calendrical.Islamic.Rgsa` — observational Islamic calendars using actual crescent visibility computed by `Astro.new_visible_crescent/3` (Odeh 2006 criterion). The two share a private `Calendrical.Islamic.Visibility` helper and differ only in observation location (Cairo vs Mecca al-Masjid al-Ḥarām).

  * `Calendrical.Hebrew` — arithmetic Hebrew calendar with the *molad of Tishri* and *Lo ADU Rosh* postponement rules. Public API uses CLDR's Tishri = 1 month numbering with month 6 (Adar I) only valid in leap years. Overrides `month_of_year/3` to return `{7, :leap}` for Adar II so localization picks up the CLDR `7_yeartype_leap` variant.

  * `Calendrical.Chinese`, `Calendrical.Korean` (Dangi), and `Calendrical.LunarJapanese` — lunisolar calendars sharing a `Calendrical.Lunisolar` base implementation. Use `Astro` for lunar phase and winter solstice calculations at Beijing/Seoul/Tokyo respectively.

* `Calendrical.Composite` — a `defmacro __using__` template for building composite calendars that use one base calendar before a specified date and a different calendar after. Supports any number of transitions chained together. The pre-built `Calendrical.England` and `Calendrical.Russia` modules demonstrate the historical Julian-to-Gregorian transitions.

* `Calendrical.Era` — an `@after_compile` hook that auto-generates a `Calendrical.Era.<CalendarType>` module from CLDR era data. Calendars `use Calendrical.Behaviour` get era support for free without writing any era boundary code. ETS-based locking coordinates module creation for calendars that share a `cldr_calendar_type`.

* `Calendrical.localize/3` — locale-aware names for `:era`, `:quarter`, `:month`, `:day_of_week`, `:days_of_week`, `:am_pm`, and `:day_periods` parts of any date. Falls through to all 766+ CLDR locales available from `Localize.Calendar`. Handles the CLDR `_yeartype_leap` variant for Hebrew Adar II without needing `month_patterns` substitution.

* `Calendrical.strftime_options!/1` — returns a keyword list compatible with `Calendar.strftime/3` so the standard library's formatter can produce locale-aware output for any Calendrical calendar.

* `Calendrical.shift_date/4` and `Calendrical.shift_naive_datetime/8` — calendar-aware date/datetime shifting that supports the standard `Date.shift/2` and `NaiveDateTime.shift/2` APIs across every Calendrical calendar.

* `Calendrical.Interval` — `Date.Range` for years, quarters, months, weeks, and days in any supported calendar. The `Calendrical.Interval.relation/2` function implements Allen's interval algebra (precedes, meets, overlaps, contains, …).

* `Calendrical.Kday` — finds the *n*-th occurrence of a given weekday relative to a date (e.g. "the second Tuesday in November", "the last Sunday before Christmas").

* `Calendrical.FiscalYear` — pre-built fiscal calendars for 50+ territories (US, AU, UK, JP, …). The `Calendrical.FiscalYear.calendar_for/1` factory creates a fiscal calendar for any supported ISO 3166 territory code.

* `Calendrical.Format` and `Calendrical.Formatter` — calendar formatting via a behaviour-based plugin system. Includes `Calendrical.Formatter.HTML.Basic`, `Calendrical.Formatter.HTML.Week`, and `Calendrical.Formatter.Markdown` for rendering calendars to HTML and Markdown. Custom formatters can be added by implementing the `Calendrical.Formatter` behaviour.

* `Calendrical.Sigils` — `~d` literals for any registered calendar. Supports the inbuilt calendars (`~d[2024-09-01 Calendrical.Hebrew]`), fiscal calendars (`~d[2024-01-01 Calendrical.FiscalYear.US]`), and user-defined calendars resolvable via `Calendrical.Preference.calendar_module/1`.

* `Calendrical.Parse` — parses ISO-8601 date and datetime strings into the calling calendar via `parse_date/1`, `parse_naive_datetime/1`, and `parse_utc_datetime/1`.

* `Calendrical.Preference` — `calendar_from_locale/1` and `calendar_from_territory/1` return the preferred calendar for a CLDR locale or ISO 3166 territory.

* `Calendrical.Ecclesiastical` — Reingold-style algorithms for the dates of Christian liturgical events in a given Gregorian year, organized into three traditions:

  * **Western** (Roman Catholic / Anglican / most Protestants, Gregorian *computus*, results returned as `Calendrical.Gregorian` dates): `easter_sunday/1`, `good_friday/1` (two days before), `pentecost/1` (49 days after), `advent/1` (the Sunday closest to 30 November), `christmas/1` (25 December), `epiphany/1` (first Sunday after 1 January, US observance).

  * **Eastern Orthodox** (Julian *computus*, results returned as `Calendrical.Julian` dates so the calendar context is visible): `orthodox_easter_sunday/1`, `orthodox_good_friday/1` (two days before), `orthodox_pentecost/1` (49 days after), `orthodox_advent/1` (the start of the *Nativity Fast* on 15 November Julian — Eastern Orthodoxy has no movable "Advent Sunday" equivalent), `eastern_orthodox_christmas/1` (25 December Julian, projected onto the Gregorian calendar).

  * **Astronomical** (the World Council of Churches' 1997 Aleppo proposal for unifying Western and Eastern Easter; not currently used by any Church, included for comparison; year range restricted to 1000..3000): `astronomical_easter_sunday/1` (first Sunday strictly after the astronomical Paschal Full Moon), `astronomical_good_friday/1` (two days before), `paschal_full_moon/1` (the astronomical PFM itself, computed via `Astro.equinox/2` and `Astro.date_time_lunar_phase_at_or_after/2`).

  Plus `coptic_christmas/1` (29 Koiak Coptic) which doesn't fit cleanly into any of the three traditions.

  The module's moduledoc includes a comparison table showing the three Easter computations side-by-side.

* Eleven exception modules in `lib/calendrical/exception/`, one per file, modeled after the Localize convention. Each has semantic struct fields, an `exception/1` constructor that takes a keyword list, and a `message/1` callback that uses `Gettext.dpgettext/5` for translation:

  * `Calendrical.IncompatibleCalendarError` — fields `:from`, `:to`.
  * `Calendrical.IncompatibleTimeZoneError` — fields `:from`, `:to`.
  * `Calendrical.InvalidCalendarModuleError` — field `:module`.
  * `Calendrical.InvalidDateOrderError` — fields `:from`, `:to`.
  * `Calendrical.MissingFieldsError` — fields `:function`, `:fields`.
  * `Calendrical.InvalidPartError` — fields `:part`, `:valid_parts`.
  * `Calendrical.InvalidTypeError` — fields `:type`, `:valid_types`.
  * `Calendrical.InvalidFormatError` — fields `:format`, `:valid_formats`.
  * `Calendrical.IslamicYearOutOfRangeError` — fields `:year`, `:min_year`, `:max_year`.
  * `Calendrical.Formatter.UnknownFormatterError` — field `:formatter`.
  * `Calendrical.Formatter.InvalidDateError` — field `:date`.
  * `Calendrical.Formatter.InvalidOptionError` — fields `:option`, `:value`.

* `Calendrical.Gettext` — gettext backend for the Calendrical library, using the `"calendrical"` domain with four contexts: `"calendar"`, `"date"`, `"format"`, and `"option"`.

* Embedded CLDR Umm al-Qura reference data sourced from R.H. van Gent's Utrecht University dataset (1356–1500 AH), cross-referenced against the KACST published tables. The data is encoded as compile-time module attributes and consumed via O(1) and O(log n) lookup.

### Changed (vs. `ex_cldr_calendars`)

* All `Cldr.Calendar.*` module names renamed to `Calendrical.*`. The detailed renaming map is in [`guides/migration.md`](guides/migration.md).

* The `:cldr_backend` option and the entire backend-module architecture have been removed. Calendrical reads CLDR data directly from `Localize.Calendar` at runtime; no compile-time backend module is required. Functions that previously took a `:backend` parameter no longer accept one.

* Error returns use the modern Elixir convention `{:error, %Exception{}}` instead of the legacy two-tuple form `{:error, {ExceptionModule, "message"}}`. Callers can pattern-match on the exception's structured data fields (e.g. `%Calendrical.MissingFieldsError{function: f, fields: fs}`).

* Exception names ending in non-`Error` suffixes have been renamed to use the `Error` suffix consistently with Localize (`Calendrical.MissingFields` → `Calendrical.MissingFieldsError`, `Calendrical.InvalidCalendarModule` → `Calendrical.InvalidCalendarModuleError`, etc.).

* `Calendrical.Hebrew` now uses CLDR's Tishri = 1 month numbering instead of Reingold's Nisan = 1 numbering. The previous numbering produced wrong localized month names because CLDR Hebrew data uses Tishri = 1.

* `Calendrical.shift_date/4` and `Calendrical.shift_naive_datetime/8` now apply duration units in the standard order (years → months → weeks → days), matching the Elixir stdlib `Date.shift/2` convention. The old `Cldr.Calendar.plus(date, %Duration{})` applied units in the opposite order.

* `Calendrical.Duration` has been removed. Use Elixir's built-in `%Duration{}` struct (since Elixir 1.17) and `Date.diff/2` instead.

* The `plus/minus` callbacks have been removed from the `Calendrical` behaviour. Calendar arithmetic is now driven exclusively by `Date.shift/2` / `NaiveDateTime.shift/2`, which delegate to the calendar's `shift_date/4`, `shift_time/5`, and `shift_naive_datetime/8` callbacks.

* All conditional code that supported Elixir versions older than 1.17 has been removed. Calendrical now requires **Elixir 1.17+** and **Erlang/OTP 26+**, matching Localize. Removed 24 obsolete `Code.ensure_loaded?` / `function_exported?` / `Version.match?` guards across 7 files.

* `Calendrical.paschal_full_moon/1` has moved to `Calendrical.Ecclesiastical.paschal_full_moon/1`. The new home is alongside the rest of the Christian-calendar functions.

### Removed

* `Cldr.Calendar.Duration` — replaced by Elixir's built-in `%Duration{}`.

* The `MyApp.Cldr.Calendar.*` backend modules and the `cldr_backend_provider/1` callback. All locale data is now read from `Localize` at runtime.

* `Calendrical.plus/{4,5,6}`, `Calendrical.minus/{4,5,6}`, the `plus/6` callback in `Calendrical.Behaviour`, and the corresponding `:months` clause in `Calendrical.Base.Month` and `Calendrical.Base.Week`. Use `Date.shift/2` / `NaiveDateTime.shift/2` instead.

### Calendars

This release introduces 17 calendar implementations covering every CLDR-acceptable calendar type. See [`guides/calendar_summary.md`](guides/calendar_summary.md) for the full list grouped by family, with month structures, leap-year rules, and reference dates.
