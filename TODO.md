# TODO

Calendrical's open work. Design documents live in `plans/`.

## Open

* [ ] **The Julian calendars answer with no year unlike the Gregorian** — `Calendrical.Julian.days_in_month(2)` is `{:error, :unresolved}`, a value the `days_in_month/1` callback does not declare (an integer, `{:ambiguous, range}` or `{:error, :undefined}`), where `Calendrical.Gregorian.days_in_month(2)` is `{:ambiguous, 28..29}`; and `months_in_year/0` is not defined, though every Julian year has twelve months, where `Calendrical.Gregorian.months_in_year()` is `12`. `Jan1`, `March1`, `March25`, `Sept1` and `Dec25` answer the same, and `test/julian_variants_test.exs` and `test/coverage_arithmetic_test.exs` pin `:unresolved`. `months_in_year/0` is an optional callback, so its absence breaks no contract, but a caller has to treat the Julian calendars apart. Found from Tempo, 2026-10-04, at `ad5ff77`.

* [ ] **Decide the astronomical Umm al-Qura rule after 1450 AH** — reviewed: it is KACST's rule to 1450 AH (335 of 336 months), and from 1451 AH KACST's projected table and ICU's follow a stricter one, moonset at least 19.5 minutes after sunset or a moon at least 18 hours old (598 of 600 and 287 of 287 months). It is not a crescent-visibility criterion (Yallop and Odeh fail), and ICU carries KACST's table without a rule; find the criterion behind KACST's projected months before choosing. Analysis in [plans/umm-al-qura-astronomical.md](plans/umm-al-qura-astronomical.md).

## Done

* [x] **`days_in_month/1` answers with no year in every calendar** — the fifteen calendars built on `Calendrical.Behaviour` that kept its `{:error, :undefined}` default, and `Calendrical.Reform.Sweden.Transitional`, answer the month's length or `{:ambiguous, range}`, checked for every month against `days_in_month/2` over a span of years by `test/days_in_month_without_year_test.exs`. Found from Tempo. 2026-10-04, v1.4.0.

* [x] **Umm al-Qura follows ICU's table after KACST's** — 1501 to 1600 AH are ICU4C's months (`priv/umm_al_qura_icu_month_lengths.csv`), where they were civil (430 of 1,200 months began on another day); with KACST's 1 to 1500 AH, which match ICU's table exactly from 1300, the calendar is ICU's from 1300 AH on, and before 1300 keeps KACST's months, documented (user, 2026-10-03). 2026-10-03, v1.4.0.

* [x] **`Calendrical.UnsupportedDateRangeError` carries its range as data** — the Islamic visibility calculations give `range: :jpl_ephemeris`, written as a whole translated sentence, where an English phrase was bound into the message; Astro reports no ephemeris bounds, so the text names the source (user, 2026-10-03). 2026-10-03, v1.4.0.

* [x] **`:begins_or_ends` must agree with `:first_or_last`** — no code read it; it now names the same choice for a calendar of weeks, a mismatched pair is an error and an omitted one follows `:first_or_last`, and a month calendar uses neither (user, 2026-10-03). Breaking. Held by `test/begins_or_ends_test.exs`. 2026-10-03, v1.4.0.

* [x] **A lunisolar day reads back in the year its new year begins** — the year was counted in mean years from the epoch, which is 165 days into `Calendrical.LunarJapanese`'s year 1, so its first day of year -10001 read back as -10002; it is now the inverse of `mid_year/3`'s placing of years. Held by `test/lunisolar_year_round_trip_test.exs`. 2026-10-03, v1.4.0.

* [x] **A month or week calendar's day of the era follows its calendar year's era** — `day_of_era/3` took the Gregorian date's era where `year_of_era/3` took the calendar year's, so NRF's year 0 days in AD 1 (34) and the fiscal years' (90 to 184) disagreed; era 1 now counts from calendar year 1's first day and era 0 back from year 0's last. Breaking for the count. Held by `test/day_of_era_test.exs`. 2026-10-03, v1.4.0.

* [x] **`Calendrical.TimeZone.resolve/3` delegates to Localize** — its own resolver, with a table of abbreviations read in every locale and a repeated hour read in daylight time, is replaced by `Localize.DateTime.Timezone.resolve/3`, which reads the locale's CLDR names and reads a repeated hour in standard time, as ICU does. Breaking. 2026-10-03, v1.4.0.

* [x] **A composite names a date from the CLDR calendar in effect on it** — every composite's `cldr_calendar_type/0` was `:gregorian`; it is the members' shared type or the last member's, and the new optional `cldr_calendar_type/3`, which Localize asks for a date, answers with the member in effect (user, 2026-10-03), so `Calendrical.Reform.Japan` writes 1872 as the Chinese calendar does and 1873 as the Japanese. Needs Localize's `Localize.Calendar.date_calendar_type/1`. Held by `test/composite_cldr_type_test.exs`. 2026-10-03, v1.4.0.

* [x] **A day with no date of its own is written as the next day that has one** — a shift or conversion into England's 1 January to 24 March 1156 or Russia's September to December 1699 answered the shared date, which names a day a year away (`Date.shift(~D[1155-12-15 Calendrical.Reform.England], month: 1)` was 1155-01-15); it answers the first later dated day, as a shift into a reform's gap does (user, 2026-10-03). Held by `test/composite_dateless_days_test.exs` for every composite. 2026-10-03, v1.4.0.

* [x] **A composite counts only the days a month has** — `days_in_month/2` is 0 for a month no day carries and `months_in_year/1` the last month with days, 0 for a year with none: England's 1751, Russia's 1492 and Japan's 1229 to 1872 answered the member calendar's months. Held by `test/composite_month_days_test.exs`. 2026-10-03, v1.4.0.

* [x] **Umm al-Qura has dates outside KACST's tables** — before 1 AH and after 1500 AH its dates are `Calendrical.Islamic.Civil`'s, as ICU falls back to it, joined to the tables without a gap; nothing raises `IslamicYearOutOfRangeError` and the year before 1 AH is 0. Held by `test/islamic_umm_al_qura_civil_test.exs` against ICU's civil formulas. 2026-10-03, v1.4.0.

* [x] **The Persian calendar has dates outside Gregorian 1001 to 3000** — years outside Persian 380 to 2378 follow ICU's arithmetic Persian calendar (33-year cycle with ICU's corrections after 2378), which agrees with the equinox at both joins; nothing raises `UnsupportedDateRangeError` and years before 1 are numbered from 0. Held by `test/persian_arithmetic_test.exs` against ICU's test dates and leap rule. 2026-10-03, v1.4.0.

* [x] **`Calendrical.strftime/3` answers errors and passes `Calendar.strftime/3`'s options through** — it raised on an invalid locale, format, option or value and dropped options such as `:preferred_date`; it now returns `{:ok, string}` or `{:error, exception}`, with `strftime!/3` for the string. 2026-10-03, v1.4.0.

* [x] **`Calendrical.strftime/3` names the month and the day from the date** — it named them by the date's fields, so a calendar of weeks raised from week 13 and named a week as a month, Hebrew, Chinese leap and fiscal months were misnamed, and every calendar whose weeks begin on another day than Monday named the wrong day (1 January 2019 "Wednesday" in Hebrew). It now asks `Localize.Calendar.localize/3`; `strftime_options!/1` documents that it names by the field numbers. Held by `test/strftime_test.exs`. 2026-10-03, v1.4.0.

* [x] **`iso_week_of_year/3` gives the ISO week of the day a fiscal calendar's date names** — `Calendrical.Base.Month` read the date's fields as a Gregorian date, so the five fiscal month calendars gave the wrong week (`Calendrical.FiscalYear.US.iso_week_of_year(2019, 1, 1)`, 1 October 2018, was `{2019, 1}` and is `{2018, 40}`) and raised `ArgumentError` where the fields name no Gregorian day. Held for 22 calendars over every day of 2018 to 2020 against `:calendar.iso_week_number/1` by `test/iso_week_of_year_test.exs`. 2026-10-03, v1.4.0.

* [x] **`:year` numbers a month or week calendar's year by the Gregorian year it begins or ends in** — `:beginning` and `:ending` raised `FunctionClauseError` in two pairings with `:first_or_last` and numbered the year the other way in the other two, and a month calendar read `first_or_last: :last` as making `:month_of_year` its last month; no fiscal calendar relied on it (the territory fiscal years use `:majority`). Held for every kind, pairing and month by `test/year_numbering_test.exs`. 2026-10-03, v1.4.0.

* [x] **A composite refuses changes of calendar it cannot keep** — a change on a day its calendar does not have, a calendar that is no calendar module, a composite or a calendar of weeks, two changes on one day, and a calendar numbering its first year before the last of the one before (Hebrew, then Gregorian from 1900) are errors, documented in `Calendrical.Composite`; `year/1` runs between the year's days that have dates of their own, never backwards. 2026-10-03, v1.4.0.

* [x] **A composite's `diff/3` compares the day `plus/6` reaches** — it read back the date written for that day, which names another day where a day has no date of its own, and stepped to its count from the difference of the years' numbers: `Calendrical.Reform.England.diff({1155, 6, 15}, {1155, 12, 20}, :months)` was 8 and is 6, and across `Calendrical.Reform.Japan`'s change from 1228 to 1873 a count of years took a minute and of months did not answer in four, where both answer at once, as `Localize.Duration.new/2` between two such dates does. 2026-10-03, v1.4.0.

* [x] **A composite year that runs through days with no dates is counted by its days** — the first and last days of a year were taken from the dates of `year/1`, which name other days where two stretches of days carry the same dates: England's 1155, of 449 days, had 13 weeks and no day past its 83rd by number, and a year that begins in such days numbered its weeks from -33. `Calendrical.Base.Common.year_days/2` asks a composite for the days themselves. 2026-10-03, v1.4.0.

* [x] **The first and last days of a year come from the calendar's `year/1`** — `first_day_of_year/2`, `last_day_of_year/2`, the two Gregorian-day functions and `date_from_day_of_year/3` answer in every calendar and for `Calendar.ISO`, where six function heads raised `UndefinedFunctionError` in 21 of 28 kinds of calendar, and three for `Calendar.ISO`, and the first day was always month 1, day 1. 2026-10-03, v1.4.0.

* [x] **A composite reads a date in the calendar that has its year** — where the calendar a date falls in by the order of its year, month and day has no day of that year, so January to August 1493 are dates of `Calendrical.Russia`; of 88,583 days about the changes of 43 composites 1,206 did not read back and one does not (England's 29 February 1156, left with the February its year, month and day name). A date before year -9999 is the base calendar's, where it raised. 2026-10-03, v1.4.0.

* [x] **A composite shifts by years and months in the calendar in effect** — `Date.shift/2` measured a year from the first of the month, no date where a change of calendar begins a month part of the way through or a year style splits it: of 956,351 shifts about the changes of 49 Julian and Gregorian composites 6,645 were wrong (670 in `Calendrical.Reform.England`) and none is, against the rule written out on the calendar's days, a year across Japan's 1873 change answers in milliseconds, where it did not in four minutes, and a year walked across a change is as many months as the calendar in effect counts, where it was twelve. 2026-10-03, v1.4.0.

* [x] **Composite calendars are created in the compiler server** — `Calendrical.Composite.new/2` and `Calendrical.Reform.calendar_for/1` defined the module themselves, so 23 of 24 processes creating the same calendar at once raised `CompileError`; they go through `Calendrical.Compiler` as `Calendrical.new/3` does. 2026-10-03, v1.4.0.

* [x] **The Gettext backend interpolates MessageFormat 2** — `Calendrical.Gettext` uses `Localize.Gettext.Interpolation`, and the fourteen messages of the thirteen exceptions are `~t` sigils with `{$name}` placeholders, extracted to `priv/gettext/calendrical.pot`; `message/1` no longer raises in the two exceptions where it did. 2026-10-03, v1.4.0.

* [x] **`Julian.Dec25` and `Sept1` number a year by the Julian year it ends in** — as C. R. Cheney's *A Handbook of Dates* sets out the Nativity style, and as the Byzantine year of the world is counted (user, 2026-10-02): year 1100 begins on 25 December 1099 and on 1 September 1099, where each began a year later. `use Calendrical.Julian` takes `:year` (`:beginning`, the default, `:ending` or `:majority`), and no year is numbered 0 in any of them. Breaking. 2026-10-02, v1.4.0.

* [x] **A composite of two Islamic calendars keeps each one's count of the era's days** — left as it is and documented (user, 2026-10-02): each Islamic calendar names its eras from its own CLDR calendar, and next to another `Calendrical.Islamic.Tbla`, which begins the Hijri era a day earlier, counts a day of the era twice or leaves one out. 2026-10-02, no change.

* [x] **The docs of `Calendrical.new/3` and `calendar_from_territory/1` describe Calendrical** — they pointed at `ex_cldr_calendars` and an optional `ex_cldr_calendars_persian`, named `:first` and `:last` for `:year`, and gave defaults `:weeks_in_month` and `:min_days_in_first_week` do not have. 2026-10-02, v1.4.0.

* [x] **A composite calendar counts an era's days in one count** — `day_of_era/3` gave the member calendar's own count, which stepped at every change of calendar an era runs through (back a day at each of the 34 Julian to Gregorian reforms, by 82 and 84 days at England's changes of new year's day); it counts on from the era's first day in the calendar in effect when the era began, or back from its last in the one in effect when it ended. 2026-10-02, v1.4.0.

* [x] **`Calendrical.Reform.Sweden.Transitional` has no year 0** — outside 1700 to 1712 it answers as the Julian calendar it is: `plus/6` and `diff/3` step from 1 BC to AD 1, `valid_date?/3` accepts December of 1 BC and refuses year 0, and its eras, days of era and extended year are the Julian calendar's, on every day of 8 BC to AD 8. 2026-10-02, v1.4.0.

* [x] **A calendar of weeks' `days_in_month/2` counts a week's seven days** — it follows the month field of its dates, their week (user, 2026-10-02), so `Date.days_in_month/1`, `Date.end_of_month/1` and every other `Date` function name a date the calendar has; a period of its pattern is `month/2`, and `months_in_year/1` stays 12. Breaking for a caller that passed a pattern month. 2026-10-02, v1.4.0.

* [x] **`extended_year/3` counts a Julian year BC from 0** — 1 BC, year -1, is 0, as TR35 defines the extended year and ICU4C counts it, in `Calendrical.Julian`, its new-year variants and the composite calendars. The Buddhist, ROC, Chinese, Korean and Vietnamese calendars keep their own year, where ICU4C writes a Gregorian one (user, 2026-10-02). 2026-10-02, v1.4.0.

* [x] **`interval/3` and `interval_stream/3` order dates by their days** — they took the earlier of their two dates from `Date.compare/2`, which orders two dates of one calendar by their fields and never asks the calendar, so in the Julian new-year calendars, where 1 January follows 31 December of the same year, a run across January was wrong. Localize's relative time, durations and parsed ranges order dates the same way, held to these calendars by `test/localize_periods_test.exs`. 2026-10-02, v1.4.0.

* [x] **The parse callbacks answer every text, and a week date reads back** — `parse_date/1`, `parse_naive_datetime/1` and `parse_utc_datetime/1` answer malformed text with `{:error, :invalid_format}` in every calendar (11,648 malformed inputs across 32 calendars), where letters raised `ArgumentError`, a negative year is checked as itself, and a calendar of weeks writes "0004-W09-7" for year 4. Asserted by the contract test. 2026-10-02, v1.4.0.

* [x] **A calendar of weeks names its months from CLDR's generic calendar** — its `cldr_calendar_type/0` is `:generic`, "M01" to "M12", since its months are the unnamed periods of its pattern of weeks, and its eras keep the Gregorian names (user, 2026-10-02). 2026-10-02, v1.4.0.

* [x] **A date callback answers only for a date its calendar has** — every calendar's date callbacks return `{:error, :invalid_date}` for a date its `valid_date?/3` rejects and a `Calendrical.MissingFieldsError` for one missing a field, through `Calendrical.Compiler.DateCheck` and asserted for every calendar by the contract test, where they raised or answered in up to 25 calendars. 2026-10-01, v1.4.0.

* [x] **A month calendar numbers a month's own weeks** — `week_of_month/3` with a first day of the week follows TR35's rule for a year in each month, where it laid the year's weeks over 4-4-5 periods and differed from that rule on about 30% of days in every such calendar. 2026-10-01, v1.4.0.

* [x] **Shifting brings the day into the month reached once** — `Date.shift/2` and `NaiveDateTime.shift/2` add years and months together, as `Calendar.ISO` (460,320 date and 73,440 date-time shifts agree) and Temporal's `NonISODateAdd` do, weeks and days as calendar days, and a week calendar's months place the day once. 2026-09-30, v1.4.0.

* [x] **Shifting by weeks and days, and a date by a time unit** — neither was a defect: a naive date-time has no daylight saving, so its day was always a calendar day, and `DateTime.shift/3` converting back at the offset before the shift is Elixir's, the same for `Calendar.ISO`; `Date.shift/2` rejects a time unit itself, and the callback raises as `Calendar.ISO.shift_date/4` does. 2026-09-30, no change.

* [x] **Era and year answers match CLDR 49 and ICU4C 78.3** — no calendar raises before its first era, and Coptic and Ethiopic eras, lunisolar cyclic years, the Julian new-year variants and composites answer as CLDR and ICU do. 2026-09-29, v1.4.0.
