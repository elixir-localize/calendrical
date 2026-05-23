# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.7.0] — 2026-05-23

### Bug Fixes

* `Calendrical.Time.parse/2` no longer lets narrow day-period markers (en's "a"/"p") consume the first letter of an adjacent capture. Previously `"11:30 PST"` against a `h:mm a v` pattern could match day_period="P" and zone="ST" (silently shifting 11:30 → 23:30 and losing the leading "P" of the zone); the day-period regex now requires a non-letter (or end of input) immediately after the match.

### Added

* `:as` option on `Calendrical.parse/2`, `Calendrical.Date.parse/2`, `Calendrical.Date.parse_range/2`, `Calendrical.Time.parse/2`, and `Calendrical.DateTime.parse/2`. Pass `as: :map` to get a bare field map containing only what the input actually supplied (`"May 5"` → `%{calendar: Calendar.ISO, month: 5, day: 5}`, `"11 am"` → `%{hour: 11}`, `"2026"` → `%{year: 2026}`) instead of a struct with synthesised defaults — useful for downstream libraries that need the unresolved partial.

## [0.6.0] — 2026-05-23

### Breaking changes

* `Calendrical.DateParseError`, `TimeParseError`, `DateTimeParseError`, `DateRangeParseError`, and `ParseError` no longer carry a `:message` struct field. The human-readable message is materialised by `Exception.message/1` from the semantic fields (`:input`, `:locale`, `:calendar`, `:reason`, `:from`, `:to`, `:cause`, `:attempts`). Pattern-match on `:reason` (and other structural fields) rather than parsing the rendered string. `DateRangeParseError` now declares `@behaviour Localize.Exception` and exposes `reason_atoms/0` for the closed set of failure categories; the `:inverted` reason carries `:from`/`:to` Date endpoints instead of stuffing them into `:input`.

### Bug Fixes

* `Calendrical.Date.parse_range/2` now returns a `Date.Range` whose endpoints are in the calendar named by the `:calendar` option (matching `parse/2`), instead of always returning Calendar.ISO endpoints. `Date.Range` supports any calendar provided both endpoints share it, so non-ISO ranges are well-formed.

* Month, day, era, quarter, and day-period name matching is now case-insensitive per CLDR TR35 §6.5 (Lenient Parsing). Previously `"23 Mai"` (capitalised) failed to parse in French because the parser case-sensitively matched the lowercase CLDR form "mai"; `"23 mai"` worked. All four parsers now accept any case for locale name fields.

* A literal space in a CLDR date pattern now requires at least one whitespace character in the input (previously zero-or-more). Inter-field gaps with no explicit pattern separator stay optional. This prevents over-greedy matches like `"mai23"` binding to a `MMMM d y` pattern as month=mai, day=2, year=3.

### Added

* `Calendrical.parse/2` — unified locale-aware parser that dispatches to the appropriate sub-parser when the input shape is not known up-front. Tries interval, date, time, then datetime, and returns `{:ok, value}` where `value` is a `Date`, `Time`, `NaiveDateTime`, `DateTime`, or `Date.Range`. Failures return `{:error, Calendrical.ParseError.t()}` whose `:attempts` field records each sub-parser tried.

* The `:calendar` option on all parsers now accepts either a CLDR calendar key atom (`:gregorian`, `:hebrew`, …) or a calendar module (`Calendar.ISO`, `Calendrical.Hebrew`, …). Modules are coerced via the `cldr_calendar_type/0` callback; `Calendar.ISO` is treated as `:gregorian`.

* `Calendrical.Date.parse/2` now accepts month-name + day input in either order regardless of the locale's preferred ordering. For any CLDR pattern with a name-form month (`MMM`/`MMMM`/`MMMMM`) and a numeric day, the parser also tries the reversed token order — so `"May 23"` parses in French (CLDR has `d MMM`) and `"23 May"` parses in English (CLDR has `MMM d, y`). Numeric `M`/`MM` are excluded because the swap would be ambiguous with `d`. Applies to year-bearing and weekday-bearing variants too; non-M-and-d tokens stay in place.

* ISO 8601 forms beyond Elixir stdlib are now accepted: **basic format** (`20260523`), **ordinal date** (`2026-143`), and **ISO week date** (`2026-W21-6`). `Calendrical.Date.parse/2` recognises all three in every locale as a universal escape hatch alongside the existing extended format (`2026-05-23`).

* `Calendrical.DateTime.parse/2` now accepts a space separator between date and time (`"2026-05-23 14:30:00"`) in addition to `T`. Elixir stdlib's `NaiveDateTime.from_iso8601/1` has accepted this form since 1.4; the gate has been relaxed so Calendrical does too. Common in SQL output, log lines, and human-readable timestamps.

* New parsing guide ([`guides/parsing.md`](https://hexdocs.pm/calendrical/parsing.html)) describing what each parser accepts, how Calendrical compares to Elixir stdlib, ISO 8601 coverage, and the documented variances from CLDR (case-insensitive name matching, M↔d swap, lenient separators).

## [0.5.0] — 2026-05-17

### Breaking changes

* `Calendrical.Date.parse/2` now returns the parsed `Date` in the calendar named by the `:calendar` option (e.g. `~D[5786-09-29 Calendrical.Hebrew]` for `calendar: :hebrew`), instead of always returning `Calendar.ISO`. Pass `return_calendar: :iso` to force the previous behaviour.

* `Calendrical.Date.parse_range/2` keeps returning ISO-Gregorian `Date.Range` endpoints — `Date.Range` is hard-coded to `Calendar.ISO` in Elixir stdlib.

### Added

* **TR35 date pattern letters** — `Q`/`q` (quarter, format & standalone, widths 1–5), `w` (week of year), `W` (week of month), `Y` (week-based year), `D` (day of year), `e`/`c` (local day of week, numeric & names), `F` (day-of-week-in-month). `E` weekday names are now validated against the constructed date instead of consumed and discarded.

* **TR35 flexible day periods (`B`)** — `Calendrical.Time.parse/2` recognises locale-specific flex period names (`"in the morning"`, `"at night"`, `"noon"`, `"midnight"`) and uses them to disambiguate AM/PM for 12-hour cycles when no `a` marker is present.

* **TR35 time zone resolution** — `Calendrical.DateTime.parse/2` now returns a `DateTime` (with the correct UTC offset) when the input carries a zone token. Supported: ISO offsets (`Z`, `±HH:MM`, `±HHMM`), GMT/UTC format (`GMT+10:30`), IANA zones (`Asia/Tokyo`), short abbreviations (`PST`, `EST`, `JST`, …), and CLDR locale names (`Pacific Time`). New `Calendrical.TimeZone.resolve/3`. IANA-name resolution requires the host application to depend on `:tzdata` or `:tz` (detected at runtime); without one, IANA names fall back to a `NaiveDateTime`.

* **All CLDR `availableFormats` skeletons** are iterated on parse, not just the four `dateStyle` / `timeStyle` references. The standards are themselves keys into `availableFormats`, so this both subsumes the previous narrower set AND admits inputs like `"3-5-1960"` (matches `:yMd` skeleton `"M/d/y"` under lenient separator equivalence) and `"week 20 of 2026"` (matches `:yw` skeleton `"'week' w 'of' Y"`).

* New `Calendrical.Time.Parser.parse_with_zone/2` — same as `parse/2` but also returns the captured zone string. Used by the DateTime parser; useful directly when a caller needs both the wall time and the original zone text.

* Plural-variant patterns in `availableFormats` (the `%{one: ..., other: ...}` shape on week-bearing skeletons like `:yw`) are now iterated, not silently dropped.

### Bug Fixes

* Time-zone field regex (`z`/`Z`/`v`/`V`/`O`/`X`/`x`) tightened from the previous permissive `[\p{L}\d:+\-/_]+` (which would happily eat `"midnight"`) to require zone-shaped input — ISO offsets, GMT format, IANA region/city, uppercase abbreviation, or CLDR-style capital-led name.

* Time parser no longer requires the `minute` capture — skeletons like `:Bh` (`"h B"`) that omit minutes now parse instead of erroring.

* Two-digit year pivot (`yy`) is correctly skipped for era-aware calendars (Japanese imperial, ROC) where the year is meant literally.

## [0.4.0] — 2026-05-17

### Bug Fixes

* `Calendrical.LunarJapanese.new/3`, `Calendrical.Chinese.new/3`, and `Calendrical.Korean.new/3` rejected valid `{m, :leap}` inputs in the documented traditional notation — the validator compared the user's traditional month number against the ordinal position returned by `leap_month/1`, which is always off by one. The check now correctly converts ordinal to traditional before comparing, the private helper has been renamed `valid_traditional_date?/5` to disambiguate from the 3-arity `valid_date?/3` callback used by `Date.new/4`, and the public `Date.new/4` ordinal contract is unchanged.

* Test support module renamed from `Calendrical.Date` to `Calendrical.Test.DateGenerator` to free the `Calendrical.Date` namespace for the new parser module. Affects `test/property_test.exs` and `test/day_of_week_test.exs` only — no public API impact.

### Added

* `traditional_leap_month/1` on each of the three lunisolar calendars (`Calendrical.LunarJapanese`, `Calendrical.Chinese`, `Calendrical.Korean`), returning the traditional (1..12) number of the intercalary month — the number the leap month repeats — as a companion to `leap_month/1` which returns the ordinal position (1..13).

* `Calendrical.Time.parse/2` and `Calendrical.DateTime.parse/2` — locale-aware time and date-time parsers completing the parser trio alongside `Calendrical.Date.parse/2`, TR35-compliant for hour-cycle resolution, day-period names, fractional seconds, and CLDR glue patterns. See the moduledocs for the day-period inheritance and datetime-glue backtracking strategy.

* `Calendrical.TimeParseError` and `Calendrical.DateTimeParseError` — structured errors carrying `:input` and `:locale`.

* `Calendrical.Date.parse/2` — locale-aware parser for user-typed date strings across every Calendar-behaviour module exposing `cldr_calendar_type/0` (Gregorian, Buddhist, Japanese imperial, Islamic, Persian, Hebrew, ROC, Coptic, Ethiopic, Indian, …). Handles CLDR `lenient-scope-date` separator equivalences, non-Latin digit transliteration, 2-digit year pivoting, and era markers — see `Calendrical.Date.Parser` for the full strategy.

* `Calendrical.Date.parse_range/2` — locale-aware range parser. Accepts either a single string (split on CLDR's `intervalFormatFallback` separator) or a `{from, to}` tuple, with CLDR interval-skeleton inheritance so `"May 5 – May 10, 2026"` parses even though the left endpoint has no year.

* `Calendrical.DateParseError` and `Calendrical.DateRangeParseError` — structured errors carrying `:input`, `:locale`, `:calendar`, plus `:reason` and `:cause` for ranges.

### Documentation

* Each lunisolar calendar's moduledoc now has a "Two month numbering conventions" section explaining the difference between **ordinal** months (used by `Date.t`, `Date.new/4`, `Date.convert/2`, and the `Calendar` callbacks) and **traditional** months (used by `new/3` and the return value of `lunar_month_of_year/1`). The previous undocumented dichotomy could silently produce dates one full lunar month off after the intercalary in leap years.

* The `new/3` and `new!/3` docstrings on each lunisolar calendar now state explicitly that the `lunar_month` argument is **traditional** (1..12 with `{m, :leap}` for the intercalary), with examples showing how the traditional number maps to the ordinal stored on the resulting `Date.t` struct.

## [0.3.1] — 2026-04-25

### Bug Fixes

* Remove unnecessary require.

## [0.3.0] — 2026-04-22

### Bug Fixes

* Fixes mapping CLDR calendar types to the implementation module name.

## [0.2.0] — 2026-04-16

This is the first release of Calendrical, which consolidates the `ex_cldr_calendars` library family into a single package built on `Localize`. Functionality from the following libraries has been merged in: `ex_cldr_calendars`, `ex_cldr_calendars_persian`, `ex_cldr_calendars_coptic`, `ex_cldr_calendars_ethiopic`, `ex_cldr_calendars_japanese`, `ex_cldr_calendars_lunisolar`, `ex_cldr_calendars_islamic`, `ex_cldr_calendars_format`, and `ex_cldr_calendars_composite`.

### Added

* `Calendrical.Behaviour` — a `defmacro __using__` template that supplies sensible default implementations of every `Calendar` and `Calendrical` callback. Calendars `use` the behaviour, supply an `:epoch` (and any non-default options), define `date_to_iso_days/3` and `date_from_iso_days/1`, and override only the callbacks that differ from the defaults. Every generated function is `defoverridable`. See [`guides/calendar_behaviour.md`](https://hexdocs.pm/calendrical/calendar_behaviour.html).

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

* `Calendrical.shift_date/5` and `Calendrical.shift_naive_datetime/9` — calendar-aware date/datetime shifting that supports the standard `Date.shift/2` and `NaiveDateTime.shift/2` APIs across every Calendrical calendar.

* `Calendrical.Interval` — `Date.Range` for years, quarters, months, weeks, and days in any supported calendar. The `Calendrical.Interval.relation/2` function implements Allen's interval algebra (precedes, meets, overlaps, contains, …).

* `Calendrical.Kday` — finds the *n*-th occurrence of a given weekday relative to a date (e.g. "the second Tuesday in November", "the last Sunday before Christmas").

* `Calendrical.FiscalYear` — pre-built fiscal calendars for 50+ territories (US, AU, UK, JP, …). The `Calendrical.FiscalYear.calendar_for/1` factory creates a fiscal calendar for any supported ISO 3166 territory code.

* `Calendrical.Format` and `Calendrical.Formatter` — calendar formatting via a behaviour-based plugin system. Includes `Calendrical.Formatter.HTML.Basic`, `Calendrical.Formatter.HTML.Week`, and `Calendrical.Formatter.Markdown` for rendering calendars to HTML and Markdown. Custom formatters can be added by implementing the `Calendrical.Formatter` behaviour.

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

* All `Cldr.Calendar.*` module names renamed to `Calendrical.*`. The detailed renaming map is in [`guides/migration.md`](https://hexdocs.pm/calendrical/migration.html).

* The `:cldr_backend` option and the entire backend-module architecture have been removed. Calendrical reads CLDR data directly from `Localize.Calendar` at runtime; no compile-time backend module is required. Functions that previously took a `:backend` parameter no longer accept one.

* Error returns use the modern Elixir convention `{:error, %Exception{}}` instead of the legacy two-tuple form `{:error, {ExceptionModule, "message"}}`. Callers can pattern-match on the exception's structured data fields (e.g. `%Calendrical.MissingFieldsError{function: f, fields: fs}`).

* Exception names ending in non-`Error` suffixes have been renamed to use the `Error` suffix consistently with Localize (`Calendrical.MissingFields` → `Calendrical.MissingFieldsError`, `Calendrical.InvalidCalendarModule` → `Calendrical.InvalidCalendarModuleError`, etc.).

* `Calendrical.Hebrew` now uses CLDR's Tishri = 1 month numbering instead of Reingold's Nisan = 1 numbering. The previous numbering produced wrong localized month names because CLDR Hebrew data uses Tishri = 1.

* `Calendrical.shift_date/5` and `Calendrical.shift_naive_datetime/9` now apply duration units in the standard order (years → months → weeks → days), matching the Elixir stdlib `Date.shift/2` convention. The old `Cldr.Calendar.plus(date, %Duration{})` applied units in the opposite order.

* `Calendrical.Duration` has been removed. Use Elixir's built-in `%Duration{}` struct (since Elixir 1.17) and `Date.diff/2` instead.

* The `plus/minus` callbacks have been removed from the `Calendrical` behaviour. Calendar arithmetic is now driven exclusively by `Date.shift/2` / `NaiveDateTime.shift/2`, which delegate to the calendar's `shift_date/4`, `shift_time/5`, and `shift_naive_datetime/8` callbacks.

* All conditional code that supported Elixir versions older than 1.17 has been removed. Calendrical now requires **Elixir 1.17+** and **Erlang/OTP 26+**, matching Localize. Removed 24 obsolete `Code.ensure_loaded?` / `function_exported?` / `Version.match?` guards across 7 files.

* `Calendrical.paschal_full_moon/1` has moved to `Calendrical.Ecclesiastical.paschal_full_moon/1`. The new home is alongside the rest of the Christian-calendar functions.

### Removed

* `Cldr.Calendar.Duration` — replaced by Elixir's built-in `%Duration{}`.

* The `MyApp.Cldr.Calendar.*` backend modules and the `cldr_backend_provider/1` callback. All locale data is now read from `Localize` at runtime.

* `Calendrical.plus/{4,5,6}`, `Calendrical.minus/{4,5,6}`, the `plus/6` callback in `Calendrical.Behaviour`, and the corresponding `:months` clause in `Calendrical.Base.Month` and `Calendrical.Base.Week`. Use `Date.shift/2` / `NaiveDateTime.shift/2` instead.

* `Calendrical.Sigils` (the `~d` sigil). Elixir's native `~D` sigil has supported a trailing calendar suffix since Elixir 1.10 and works for any module implementing the `Calendar` behaviour. Use `~D[2024-09-01 Calendrical.Hebrew]` instead of `~d[2024-09-01 Hebrew]`. The `Calendrical.Sigils` sigil's other features (default of `Calendrical.Gregorian`, ISO week-date format `yyyy-Wmm-dd`, fiscal calendar shortcuts, B.C.E./C.E. era markers) are minor conveniences that did not justify maintaining a parallel sigil system. See [`guides/migration.md`](https://hexdocs.pm/calendrical/migration.html) for one-line equivalents of every removed feature.

### Calendars

This release introduces 17 calendar implementations covering every CLDR-acceptable calendar type. See [`guides/calendar_summary.md`](https://hexdocs.pm/calendrical/calendar_summary.html) for the full list grouped by family, with month structures, leap-year rules, and reference dates.
