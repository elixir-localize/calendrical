# TODO

Calendrical's open work. Design documents live in `plans/`.

## Open

* [ ] **`cardinal_month/1` names a year-ending month calendar's months a month early** — `Base.Month.cardinal_month/2` takes `month_of_year` as the month a year begins in, but with `first_or_last: :last` it is the month the year ends in, so a month calendar configured that way names its first month for the month its year ends in. A calendar of weeks is unaffected since its months became ordinal ("M01" from CLDR's generic calendar), though `Calendrical.NRF`, whose period 1 is February, showed it until then.

* [ ] **`iso_week_of_year/3` reads a fiscal calendar's date as Gregorian** — the month compiler passes `Base.Month.iso_week_of_year/3` no config, so `Calendrical.Fiscal.US.iso_week_of_year(2019, 1, 1)`, 1 October 2018 and ISO week 2018-W40, answers `{2019, 1}`.

* [ ] **A composite calendar whose members differ in CLDR type** — every composite's `cldr_calendar_type/0` is `:gregorian`, so `Calendrical.Reform.Japan`'s lunisolar dates before 1873 take Gregorian month names ("February" for the second lunar month) and no leap-month pattern. Naming them from the calendar in effect needs Localize to ask for it, or such composites to be split: a decision to make.

* [ ] **Arithmetic into days that have no dates** — where a year's number does not change on 1 January two stretches of days carry the same year, month and day and the later has no dates (England's 1 January to 24 March 1156), so `Date.shift(~D[1155-12-15 Calendrical.Reform.England], month: 1)` answers `~D[1155-01-15 Calendrical.Reform.England]`, a day 334 days earlier. Answer the next day that has a date, 25 March 1156, or an error: a decision to make.

* [ ] **A composite accepts changes of calendar it cannot keep** — `Calendrical.Composite.new/2` and `use Calendrical.Composite` take a change on a day its calendar does not have (`%{year: 1700, month: 13, day: 1}` in `Calendrical.Gregorian`), a calendar that numbers its years above the next one's first (Hebrew, then Gregorian from 1900: every Hebrew year from 1900 on reads as a Gregorian one), and two year styles in a row whose year has two stretches of days, where `year/1` makes `Date.range/2` infer a negative range and warn. Validate the changes, or document what a composite can hold.

* [ ] **A composite counts the days of a month its year does not have** — England's 1751 began on 25 March, and `days_in_month(1751, 1)` is 31, `days_in_month(1751, 2)` 28 and `months_in_year(1751)` 12: the answers of the calendar that had the year, for months it had no days of.

* [ ] **Umm al-Qura years outside the official tables** — ICU4C 78.3 falls back to the civil calendar there, and `Calendrical.Islamic.UmmAlQura` begins some years a day earlier: 1 Muharram 1178 is 1764-06-30 here and 1764-07-01 in ICU (also 607, 717, 758 and 1261 AH). Find which fallback Calendrical uses and document or change it.

* [ ] **A date before 1 AH raises in `Calendrical.Islamic.UmmAlQura`** — `naive_datetime_from_iso_days/1` raises `Calendrical.IslamicYearOutOfRangeError` (Hijri year nil), and the `Calendar` behaviour gives it no error to return, so `Date.convert/2` raises and so does `Localize.Date.parse("0500-03-15", calendar: Calendrical.Islamic.UmmAlQura)`. ICU4C's civil fallback (above) would answer it.

* [ ] **The Persian calendar raises outside Gregorian 1001 to 3000** — `valid_date?/3` answers `false` there, so its date callbacks and Localize return errors for such a date, but `months_in_year/1` and `days_in_month/2` raise `Calendrical.UnsupportedDateRangeError`, and so does converting a date outside the range into it, so `Localize.Date.parse("0001-001", calendar: Calendrical.Persian)` raises as it does for the Umm al-Qura calendar (above). Answer those callbacks, or reject the year, without raising.

* [ ] **Eras around 1 January AD 1 in `Calendrical.NRF`** — `day_of_era/3` takes the Gregorian date's era and `year_of_era/3` the calendar year's, so they disagree on NRF's fiscal year 0 days in AD 1.

* [ ] **`Calendrical.strftime/3` raises for `%B` and `%b` in a calendar of weeks** — its dates' month field holds a week, which has no name, and what the lookup answers makes `Calendar.strftime/3` raise `ArgumentError`. Write the period's CLDR generic name ("M06"), or the week.

* [ ] **`Calendrical.UnsupportedDateRangeError`'s `:range` is English prose** — the Persian calendar and the Islamic visibility calculations give it a phrase such as "dates covered by the installed JPL ephemeris", which is bound into the translated message untranslated. Carry the bounds as data and write them in the message.

* [ ] **Delegate `Calendrical.TimeZone.resolve/3` to Localize** — Localize now parses and resolves a zone in every form a locale writes (`Localize.DateTime.Timezone.parse_zone/2` and `resolve/3`) and no longer calls this module, which duplicates it with a table of abbreviations and resolves a fall-back hour to daylight time where ICU and Localize take standard.

* [ ] **`Calendrical.LunarJapanese` reads the first day of year -10001 back as year -10002** — `date_from_iso_days(date_to_iso_days(-10001, 1, 1))` is `{-10002, 1, 1}`, far outside the years its astronomy is good for; found where a composite's base calendar was given no first day.

## Done

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
