# Changelog

All notable changes to this project will be documented in this file.

The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

* Requires `astro ~> 2.5`, which ships a bundled ephemeris covering 1900–2100, so the astronomical calendars (Persian, Chinese, Korean, Lunar Japanese and the observational Islamic calendars) now work immediately after installation with no ephemeris download. `mix astro.download_ephemeris` still installs the full 1849–2150 range when a wider span is needed.

## [1.1.0] — 2026-08-05

### Added

* `Calendrical.Reform` builds per-territory Julian-to-Gregorian reform calendars from the `ncal(1)` reform-date table, via `calendar_for/1` (accepting a territory code or a `Localize.LanguageTag`) with `reforms/0` returning the full table. It prefers curated composites where they matter: `Calendrical.Reform.Sweden` models Sweden's 1700–1753 transition including the unique 30 February 1712, and `Calendrical.Reform.Japan` models the lunisolar-to-Gregorian change of 1873.

### Fixed

* `Calendrical.Julian.parse_date/1` and the naive/UTC datetime parsers validated dates with Gregorian leap rules via `Calendar.ISO`, wrongly rejecting Julian-valid dates such as 29 February 1700; they now validate against the Julian calendar.

* Composite calendars derived `days_in_month/2` from the final segment's calendar for months wholly inside an intermediate segment, returning the wrong length (e.g. February 1712 in the Swedish transitional era); the month is now answered by the calendar actually in effect.

## [1.0.0] — 2026-07-31

The first stable release, built on Localize 1.0.

### Fixed

* `Calendrical.Persian.date_from_iso_days/1` computed the month with `:math.ceil/1` in one branch and `Kernel.ceil/1` in the other, so any date after the 186th day of the Persian year carried a float month back into `date_to_iso_days/3`. The returned month was truncated and therefore correct, but the intermediate arithmetic ran on floats.

* Specifications that omitted error returns the function can actually make are corrected, so a caller reading the spec now sees every value it can receive. `Calendrical.next/3` and `previous/3` return `{:error, :not_defined}`; `Calendrical.Julian.year/1`, `quarter/2` and `month/2` return `{:error, :invalid_date}`; `Calendrical.Interval.week/1` returns `{:error, :not_defined}`; `Calendrical.Composite.new/2` returns `{:error, :must_be_a_list_of_dates | :no_calendars_configured}`; and the astronomical Ecclesiastical functions return `{:error, :year_out_of_range}`.

### Changed

* Requires `localize ~> 1.0`.

* Year-conversion helpers (`Calendrical.Roc.gregorian_year/1`, `Calendrical.Buddhist.buddhist_year/1`, the Indian and Ethiopic equivalents) and the per-calendar `date_to_iso_days/3` implementations now guard their arguments with `is_integer/1`. A non-integer argument raises `FunctionClauseError` rather than silently computing a float result.

* Dialyzer runs with the Localize flag set (`:error_handling`, `:unknown`, `:underspecs`, `:extra_return`, `:missing_return`). The exclusions in `.dialyzer_ignore.exs` are documented individually.

## [1.0.0-rc.2] — 2026-07-28

### Changed

* **Breaking:** `Calendrical.localize/3` and `Calendrical.month_names/2` rename the width option `:format` to `:style`, and `Calendrical.localize/3` renames the `:am_pm` part and its variant option to `:day_period`, aligning with Localize 1.0.0-rc.7. `Calendrical.InvalidFormatError` (fields `:format`, `:valid_formats`) becomes `Calendrical.InvalidStyleError` (fields `:style`, `:valid_styles`).

### Fixed

* `Calendrical.Behaviour` resolves the year-less `months_in_year/0` result at compile time, eliminating the dialyzer `pattern_match`/`exact_compare` warnings the generated runtime comparison produced in every calendar module.

## [1.0.0-rc.1] — 2026-07-27

### Changed

* Requires Localize `~> 1.0-rc`.

### Fixed

* Calendar-module probes (`strftime_options!/1`, `month_names/2`, `era_calendar_type/1`, `cardinal_month/3`, `cardinal_day_of_week/2`) ensure the module is loaded before `function_exported?/3`, so a cold calendar module no longer silently falls back to `:gregorian` naming or uncorrected month/day mapping.

## [0.13.0] — 2026-07-15

### Changed

* `Calendrical.TimeZone.tz_database/0` resolves the database from the `:elixir` `:time_zone_database` configuration first, then falls back to detecting a loaded implementation (`Tz` preferred over `Tzdata`). The `tzdata` dependency is removed entirely; `tz` is the database used for calendrical's own dev and test, and neither is forced on consumers. Case-insensitive IANA name canonicalisation still works when a consumer loads `tzdata` (the only database exposing a zone list); otherwise zone names resolve exact-case.

## [0.12.0] — 2026-07-06

### Fixed

* `Calendrical.new/3` returns `{:error, exception}` when runtime calendar compilation fails, instead of crashing the compiler server and every queued caller; the call timeout is raised to 30 seconds.

* `year/1` week ranges on month-based calendars return the range builder's error instead of raising a `MatchError` when a boundary date cannot be constructed.

### Changed

* Date conversion on month-based calendars with a January year start skips the year-boundary slide derivation, removing the dominant cost from the `date_to_iso_days/3` hot path.

## [0.11.0] — 2026-07-05

### Added

* `Calendrical.UnsupportedDateRangeError` is raised when a date lies outside the range an astronomical calendar can compute (Persian: Gregorian years 1001 to 3000; observational Islamic calendars: the JPL ephemeris coverage). Previously these crashed with `FunctionClauseError` or `MatchError`.

* `Calendrical.Persian.new_year_gregorian/1` and `year_end_gregorian/1` return `{:error, :year_out_of_range}` for years outside the supported equinox range instead of crashing.

* `Calendrical.TimeZone.resolve/3` resolves CLDR metazone names ("Pacific Standard Time", "Mitteleuropäische Zeit") to the representative IANA zone for the locale's territory, falling back to the metazone's golden zone. Requires `localize >= 0.45`.

### Removed

* The deprecated `Calendrical.Preference.calendar_for_territory/1` and `calendar_for_locale/1` delegates are removed. Use `calendar_from_territory/1` and `calendar_from_locale/1`.

* The parser engine modules (`Calendrical.Parser`, `Calendrical.Date.Parser`, `Calendrical.DateTime.Parser`, `Calendrical.Time.Parser`) and the Gettext backend are no longer part of the documented public API. Use the `parse/2` functions on `Calendrical`, `Calendrical.Date`, `Calendrical.DateTime` and `Calendrical.Time`.

### Changed

* Era data is now resolved from CLDR data at runtime and cached in `:persistent_term`. The generated `Calendrical.Era.<Type>` modules no longer exist; era setup no longer performs astronomy or module creation at compile time.

* Pre-Meiji Japanese era boundaries are now resolved from their lunisolar proclamation dates via `Calendrical.LunarJapanese`, correcting boundaries that were 25 days to 6 weeks early. Meiji and later remain proleptic Gregorian per government proclamation.

* Require `astro >= 2.3.3` so out-of-ephemeris moon events and out-of-range equinox/solstice return tagged errors.

* `Calendrical.Lunisolar.is_prior_leap_month?/3` is renamed to `prior_leap_month?/3`; the `is_` prefix is reserved for guard-safe macros by Elixir naming conventions.

### Fixed

* Lunisolar leap-year detection no longer misclassifies 383-day 13-month years as ordinary (45 of the 1240 lunar years from 645 CE were affected). `leap_year?/1`, `months_in_year/1`, `leap_month/1` and `days_in_month/2` now agree with the month sequence for these years in the Chinese, Korean and LunarJapanese calendars.

* Japanese era 115 (建保) now resolves astronomically to its lunisolar proclamation date (1214-01-25 proleptic Gregorian) instead of falling back to the raw Gregorian reading.

* Traditional lunisolar date validation no longer accepts a day one past the end of a month, and the default `days_in_year/1` no longer counts one day too many for the Persian, Chinese, Korean and LunarJapanese calendars.

* `year_of_era/{1,3}` and `day_of_era/3` are corrected for the Persian, Buddhist, Hebrew, Chinese, Korean, Indian, ROC and Islamic calendars. The year of era is now the calendar's own year (Persian 1405 → `{1405, 0}`), and before-eras (BCE, before ROC, before Hijra) count backwards from year zero.

* `week_of_month/1` no longer returns month 13 for dates in week 53 of a long year; the leap week belongs to month 12.

* The Julian year-shift variants (`March1`, `March25`, `Sept1`, `Dec25`) now validate leap days, compute weekdays, weeks, eras and parse dates against the Julian year that actually contains the date, instead of the variant's label year.

* `Calendrical.Formatter.Options` returns an option error instead of crashing when day names cannot be derived, and `Calendrical.Preference` falls back to the world territory when the process locale has none.

* `calendar_from_locale/1` now honours the BCP 47 `-u-ca-` and `-u-fw-` locale extensions. The pattern clauses matched a field name that no longer exists on `Localize.LanguageTag`, so explicit calendar requests such as `en-u-ca-coptic` silently fell through to the territory preference. An explicit `-u-ca-gregory` resolves through the territory so localized week conventions still apply.

* The HTML month template now closes its `<caption>` tag and separates the `id` attribute from `class`; `Calendrical.Formatter.HTML.Basic` no longer emits a deprecation warning on every rendered day.

* `Date.shift/2` and `NaiveDateTime.shift/2` on Calendrical calendars now clamp year and month shifts to the end of the target month per the `Calendar.ISO` contract. Previously an invalid date such as February 31 escaped into the returned struct.

* `Calendrical.Julian.day_of_era/3` now counts days from the era boundary (Julian 0001-01-01) instead of returning a meaningless sum; BCE days count backwards from the day before the epoch.

* `Calendrical.iso_days_to_day_of_week/1` now returns `7` for Sunday per its documented 1..7 contract, instead of `0`. `Calendrical.Kday` results are unchanged; it computes its zero-based weekday internally.

* `leap_year?/1` on the Chinese, Korean and LunarJapanese calendars now converts a date in another calendar before checking, instead of silently treating any date's year number as a year of this calendar (the clause head contained `__MODULE` — a variable, not the module — so it matched every calendar).

* `Calendrical.Julian.plus/6` no longer produces the invalid year zero: year and month arithmetic that crosses the BCE/CE boundary skips it, so year -1 plus one year is year 1.

* `Calendrical.new/3` and `Calendrical.FiscalYear.calendar_for/1` are now idempotent, returning `{:ok, module}` when the calendar module already exists instead of `{:module_already_exists, module}`.

* `Calendrical.date_from_day_of_year/3` now tags its result with the given calendar; previously a non-default calendar's field values were returned in a struct mislabelled `Calendar.ISO`.

* `day_of_week/4` on the Coptic and Ethiopic calendars accepts explicit `starting_on` weekdays (`:monday` .. `:sunday`), renumbering relative to the requested start; previously anything but `:default` raised.

* The `days_in_year/1` callback type is corrected from `Calendar.day()` (1..31) to a positive day count, and `leap_month?/0` admits the `:leap` atom the Hebrew calendar deliberately returns for Adar II.

* `first_day_for_locale/2` and `min_days_for_locale/2` lose their ignored options argument; use the 1-arity forms.

* `min_days_for_territory/1`, `first_day_for_territory/1`, `weekend/1`, `weekdays/1` and therefore `calendar_for_territory/1` no longer loop forever for a valid ISO territory absent from CLDR week data (private-use codes such as `:XX`); they take the world defaults.

* Time parsing resolves locale day-period names against the locale's own AM/PM name sets, so `午後2:30` (`:ja`) parses as 14:30 and `3:30 μ.μ.` (`:el`) as 15:30. Previously only ASCII "pm" heuristics applied and such inputs silently parsed as AM.

* Calendars built on `Calendrical.Behaviour` support `plus/6` for `:years`, `:weeks` and `:days` (previously only `:months`), so `Date.shift/2` with year, week or day durations no longer raises on the Coptic, Ethiopic, Hebrew, Persian, lunisolar and Islamic calendars.

* `plus/6` with a negative month count now normalizes into the prior year on Behaviour calendars and `Calendrical.Julian`, instead of returning an invalid negative month.

* `day_of_era/3` on the Coptic and Ethiopic calendars counts from the era boundary instead of returning a meaningless sum (the same defect fixed for `Calendrical.Julian` earlier in this release).

* The lunisolar solar-term functions work: `solar_longitude_on_or_after/3` (and the major/minor term searches built on it) no longer raises on every call, and `current_minor_solar_term/2` groups its arithmetic per Reingold & Dershowitz.

* `Calendrical.TimeZone.resolve/3` resolves CLDR localized zone names ("British Summer Time" → Europe/London) and lowercase IANA ids by canonicalizing case-insensitively against the time zone database, and rejects out-of-range offsets such as `+05:99`.

* `Calendrical.Format` accepts an explicit `:territory` option; previously any supplied territory was rejected as an invalid option.

* `Calendrical.DateTime.parse/2` recognises the CLDR atTime glue patterns and unquotes literal separators, so `"16 mai 2026 à 14:30"` parses under `:fr`.

* Day-period matching accepts ASCII spaces where CLDR ships NBSP or narrow NBSP inside a name, so `"3:30 p. m."` parses under `:es`.

* Map-mode range parsing tries day-bearing interval patterns before month/year-only ones, so `"May 5 – May 10"` with `as: :map` deterministically yields day fields instead of sometimes misreading `"10"` as a year.

* Composite calendars compute `days_in_year/1` and `days_in_month/2` correctly in a year whose new-year style changes mid-year: England's 1751 ran from Lady Day to 31 December (282 days) and its March had 7 days.

* `Calendrical.Composite.new/2` returns `{:error, :no_calendars_configured}` instead of a bare `:error` when the `:calendars` option is missing.

* `previous/3` for a `Date.Range` and `:day` returns a `Date.Range` like every other range clause; week-calendar `iso_week_of_year/4` returns its missing-fields error instead of raising; `days_in_month/1` with a non-integer month returns an error instead of raising `ArithmeticError`.

* `Calendrical.localize/3` now accepts `:cyclic_year` and returns the localized sexagesimal cycle name (2026 → "bing-wu" in `:en`, 丙午 in `:ja`). The part was rejected by option validation, and the lookup keyed on elapsed years instead of the 1..60 cycle position, so it could never match a CLDR name.

* `related_gregorian_year/3` now returns the Gregorian year in which the calendar year begins per TR35, constant across the calendar year. Previously the Behaviour calendars returned their own year number unchanged (Chinese 4663 instead of 2026), and the Coptic, Ethiopic and Julian calendars returned the Gregorian year of the date itself, drifting forward for dates past December 31.

* `Calendrical.LunarJapanese.year_of_era/{1,3}`, `day_of_era/3` and `calendar_year/3` now consult the Japanese era table, so lunisolar dates carry 元号 era years (2026 → Reiwa 8, and an era begins on its proclamation day mid-lunar-year, as the chronicles record). Previously they used the Chinese-type identity mapping and returned the raw elapsed year.

* `Calendrical.localize/3` with `:era` now renders era names for the lunisolar Japanese calendar (令和, 安政) via the new optional `era_calendar_type/0` callback, which lets a calendar take era names from a different CLDR calendar than its other localized names.

* `Calendrical.inspect/2` no longer crashes on dates and ranges in non-ISO calendars — it called an `inspect_date` function that no calendar defines. It now delegates to the Inspect protocol and also accepts the `t:Inspect.Opts.t/0` that `IEx.configure/1` passes to an `:inspect_fun`.

## [0.10.0] — 2026-07-02

### Added

* `months_in_year/0` returns the number of months in a year without needing a year — an integer for fixed-length calendars, or `{:ambiguous, first..last}` for lunisolar calendars whose month count varies with the year (e.g. the Hebrew calendar's `12..13`).

### Fixed

* `days_in_month/1` now returns `{:error, :undefined}` for a month outside the calendar's range (e.g. `days_in_month(13)`) instead of a wrapped or garbage length.

## [0.9.2] — 2026-06-30

### Fixed

* Require `astro ~> 2.3` to pick up the fix for compilation failing with `:time_zone_not_found` when a non-UTC time zone database such as `Tzdata.TimeZoneDatabase` is configured. The Persian era boundaries computed at compile time use ancient dates that such databases cannot resolve. Closes [#1](https://github.com/kipcole9/calendrical/issues/1).

## [0.9.1] — 2026-05-24

### Fixed

* `Calendrical.Date.parse_range/2` now accepts any of `-`, `–` (en-dash), `—` (em-dash), `−` (minus sign), or `‑` (non-breaking hyphen) wherever a CLDR interval pattern declares one of them. Previously the literal en-dash in CLDR's `intervalFormats` only matched the en-dash itself, so `"May 23 - 25, 2026"` (ASCII hyphen) fell through to the split-fallback path and failed.

* `Calendrical.Date.parse_range/2` now accepts wide month names where the pattern declared abbreviated (and vice versa) per CLDR TR35 §6.5 lenient parsing, so `"May 5 – June 10, 2026"` and `"May 5 – Jun 10, 2026"` both match the `MMM d – MMM d, y` skeleton and produce equal-resolution endpoints. Previously the wide form fell through to the split-fallback path and lost year inheritance.

* `Calendrical.Date.parse_range/2` now matches day-first informal orderings via token-level transformation of CLDR's month-first patterns, so `"23 - 25 May, 2026"` (cross-endpoint month-shift) and `"5 May – 10 June, 2026"` (per-endpoint month/day swap) both parse with full year inheritance. Synthesized variants are tried in addition to CLDR-canonical patterns.

* `Calendrical.Date.parse/2`, `parse_range/2`, and dependents now accept inputs that omit the structural comma in CLDR patterns like `MMM d, y` — so `"May 5 2026"` and `"23 – 25 May 2026"` parse alongside the comma-bearing forms.

## [0.9.0] — 2026-05-24

### Added

* Lenient input handling on `Calendrical.parse/2`, `Calendrical.Date.parse/2`, and `Calendrical.DateTime.parse/2`: internal double-whitespace is collapsed to a single space; abbreviated month names accept an optional trailing period (`"Jun."` matches CLDR `"Jun"`, `"janv"` matches CLDR `"janv."`); the M↔d swap variants now also produce comma-stripped and dash/slash/period-separated forms, so `"23 Feb 2013"`, `"01-Feb-18"`, `"01/Jun./2018"`, and `"01.Feb.2018"` all parse under `:en` even though CLDR ships only `MMM d, y`.

* `Calendrical.DateTime.parse/2` accepts bare space, `" - "`, and `" @ "` as universal fallback glue separators in every locale, on top of CLDR's locale-specific glue. Catches `"01/01/2018 14:44"`, `"01/01/2018 - 17:06"`, and (under day-first locales such as `:de`) `"23-05-2019 @ 10:01"` shapes common in admin UIs and human-written notes.

* Locale-aware weekday-prefix stripping — `"Sun, 01 January 2017"`, `"Tuesday, November 29, 2016"`, `"lundi, 1 janvier 2025"`, `"Wednesday 3rd March 2023 3:45 PM"`. The recognised weekday set is sourced from CLDR `format` + `stand-alone` × `wide`/`abbreviated`/`short` widths (narrow forms excluded to avoid single-letter false matches), with optional trailing `.`/`,`/`;` consumed.

* Locale-aware ordinal-affix stripping derived from CLDR's `digits-ordinal` RBNF rule. Strips suffixes for `:en` (`st`/`nd`/`rd`/`th`), `:fr` (`er`/`e`), `:es`/`:pt`/`:it` (`º`/`ª`, with optional preceding period), `:nl` (`e`), and prefixes for `:ja` (`第`); locales whose digits-ordinal rule is just digit + `.` (`:de`) are explicitly skipped because the period collides with date-field separators. Stripping runs as a retry only if the unmodified input doesn't parse, so CLDR-baked ordinal text like `"2nd quarter"` (the wide quarter name in `:en`) keeps matching its native pattern.

## [0.8.0] — 2026-05-24

### Changed

* Function and module documentation across the calendar modules (Persian, Coptic, Hebrew, Ethiopic, Ethiopic.AmeteAlem, Buddhist, Indian, ROC, Julian and its variants, Ecclesiastical, Kday, Composite, Formatter, Chinese, Korean, LunarJapanese) is now in the project's standard template with `### Arguments`, `### Returns`, and `### Examples` sections. Many functions gained their first doctest examples, taking the total doctest count from 410 to 509+.

* `Calendrical.Julian` now has a `@moduledoc` describing the proleptic Julian calendar and the year-shift variants (`Calendrical.Julian.Jan1`, `.March1`, `.March25`, `.Sept1`, `.Dec25`). Each variant now has its own short `@moduledoc` describing the historical year-style it represents.

### Fixed

* Spelling fixes in calendar docs: `calcualate` → `calculate` (Persian leap-year doc), `Arguements` → `Arguments`, `boolaan`/`booelan` → `boolean`, `Luanr` → `Lunar`, `sexigesimal` → `sexagesimal` (Chinese, Korean, LunarJapanese).

* README installation snippet now points to `~> 0.8` instead of the stale `~> 0.1.0` from the initial release.

* README LICENSE link now points to `v0.8.0` instead of `v0.1.0`.

* README Quick Start example for `Calendrical.Interval.quarter/3` now shows the expected `Date.range/2` result, matching the other examples in the block.

## [0.7.2] — 2026-05-23

### Fixed

* Require astro ~> 2.2 for the proleptic-Gregorian equinox fix.

## [0.7.1] — 2026-05-23

### Fixed

* Fix dialyzer type warnings.

## [0.7.0] — 2026-05-23

### Fixed

* `Calendrical.Time.parse/2` no longer lets narrow day-period markers (en's "a"/"p") consume the first letter of an adjacent capture. Previously `"11:30 PST"` against a `h:mm a v` pattern could match day_period="P" and zone="ST" (silently shifting 11:30 → 23:30 and losing the leading "P" of the zone); the day-period regex now requires a non-letter (or end of input) immediately after the match.

### Added

* `:as` option on `Calendrical.parse/2`, `Calendrical.Date.parse/2`, `Calendrical.Date.parse_range/2`, `Calendrical.Time.parse/2`, and `Calendrical.DateTime.parse/2`. Pass `as: :map` to get a bare field map containing only what the input actually supplied (`"May 5"` → `%{calendar: Calendar.ISO, month: 5, day: 5}`, `"11 am"` → `%{hour: 11}`, `"2026"` → `%{year: 2026}`) instead of a struct with synthesised defaults — useful for downstream libraries that need the unresolved partial.

## [0.6.0] — 2026-05-23

### Breaking changes

* `Calendrical.DateParseError`, `TimeParseError`, `DateTimeParseError`, `DateRangeParseError`, and `ParseError` no longer carry a `:message` struct field. The human-readable message is materialised by `Exception.message/1` from the semantic fields (`:input`, `:locale`, `:calendar`, `:reason`, `:from`, `:to`, `:cause`, `:attempts`). Pattern-match on `:reason` (and other structural fields) rather than parsing the rendered string. `DateRangeParseError` now declares `@behaviour Localize.Exception` and exposes `reason_atoms/0` for the closed set of failure categories; the `:inverted` reason carries `:from`/`:to` Date endpoints instead of stuffing them into `:input`.

### Fixed

* `Calendrical.Date.parse_range/2` now returns a `Date.Range` whose endpoints are in the calendar named by the `:calendar` option (matching `parse/2`), instead of always returning Calendar.ISO endpoints. `Date.Range` supports any calendar provided both endpoints share it, so non-ISO ranges are well-formed.

* Month, day, era, quarter, and day-period name matching is now case-insensitive per CLDR TR35 §6.5 (Lenient Parsing). Previously `"23 Mai"` (capitalised) failed to parse in French because the parser case-sensitively matched the lowercase CLDR form "mai"; `"23 mai"` worked. All four parsers now accept any case for locale name fields.

* A literal space in a CLDR date pattern now requires at least one whitespace character in the input (previously zero-or-more). Inter-field gaps with no explicit pattern separator stay optional. This prevents over-greedy matches like `"mai23"` binding to a `MMMM d y` pattern as month=mai, day=2, year=3.

### Added

* `Calendrical.parse/2` — unified locale-aware parser that dispatches to the appropriate sub-parser when the input shape is not known up-front. Tries interval, date, time, then datetime, and returns `{:ok, value}` where `value` is a `Date`, `Time`, `NaiveDateTime`, `DateTime`, or `Date.Range`. Failures return `{:error, Calendrical.ParseError.t()}` whose `:attempts` field records each sub-parser tried.

* The `:calendar` option on all parsers now accepts either a CLDR calendar key atom (`:gregorian`, `:hebrew`, …) or a calendar module (`Calendar.ISO`, `Calendrical.Hebrew`, …). Modules are coerced via the `cldr_calendar_type/0` callback; `Calendar.ISO` is treated as `:gregorian`.

* `Calendrical.Date.parse/2` now accepts month-name + day input in either order regardless of the locale's preferred ordering. For any CLDR pattern with a name-form month (`MMM`/`MMMM`/`MMMMM`) and a numeric day, the parser also tries the reversed token order — so `"mai 23"` parses in French (CLDR has `d MMM`) and `"23 May"` parses in English (CLDR has `MMM d, y`). Numeric `M`/`MM` are excluded because the swap would be ambiguous with `d`. Applies to year-bearing and weekday-bearing variants too; non-M-and-d tokens stay in place.

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

### Fixed

* Time-zone field regex (`z`/`Z`/`v`/`V`/`O`/`X`/`x`) tightened from the previous permissive `[\p{L}\d:+\-/_]+` (which would happily eat `"midnight"`) to require zone-shaped input — ISO offsets, GMT format, IANA region/city, uppercase abbreviation, or CLDR-style capital-led name.

* Time parser no longer requires the `minute` capture — skeletons like `:Bh` (`"h B"`) that omit minutes now parse instead of erroring.

* Two-digit year pivot (`yy`) is correctly skipped for era-aware calendars (Japanese imperial, ROC) where the year is meant literally.

## [0.4.0] — 2026-05-17

### Fixed

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

### Fixed

* Remove unnecessary require.

## [0.3.0] — 2026-04-22

### Fixed

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
