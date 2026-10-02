# TODO

Calendrical's open work. Design documents live in `plans/`.

## Open

* [ ] **`cardinal_month/1` names a year-ending month calendar's months a month early** — `Base.Month.cardinal_month/2` takes `month_of_year` as the month a year begins in, but with `first_or_last: :last` it is the month the year ends in, so a month calendar configured that way names its first month for the month its year ends in. A calendar of weeks is unaffected since its months became ordinal ("M01" from CLDR's generic calendar), though `Calendrical.NRF`, whose period 1 is February, showed it until then.

* [ ] **`iso_week_of_year/3` reads a fiscal calendar's date as Gregorian** — the month compiler passes `Base.Month.iso_week_of_year/3` no config, so `Calendrical.Fiscal.US.iso_week_of_year(2019, 1, 1)`, 1 October 2018 and ISO week 2018-W40, answers `{2019, 1}`.

* [ ] **A composite calendar whose members differ in CLDR type** — every composite's `cldr_calendar_type/0` is `:gregorian`, so `Calendrical.Reform.Japan`'s lunisolar dates before 1873 take Gregorian month names ("February" for the second lunar month) and no leap-month pattern. Naming them from the calendar in effect needs Localize to ask for it, or such composites to be split: a decision to make.

* [ ] **Umm al-Qura years outside the official tables** — ICU4C 78.3 falls back to the civil calendar there, and `Calendrical.Islamic.UmmAlQura` begins some years a day earlier: 1 Muharram 1178 is 1764-06-30 here and 1764-07-01 in ICU (also 607, 717, 758 and 1261 AH). Find which fallback Calendrical uses and document or change it.

* [ ] **A date before 1 AH raises in `Calendrical.Islamic.UmmAlQura`** — `naive_datetime_from_iso_days/1` raises `Calendrical.IslamicYearOutOfRangeError` (Hijri year nil), and the `Calendar` behaviour gives it no error to return, so `Date.convert/2` raises and so does `Localize.Date.parse("0500-03-15", calendar: Calendrical.Islamic.UmmAlQura)`. ICU4C's civil fallback (above) would answer it.

* [ ] **The Persian calendar raises outside Gregorian 1001 to 3000** — `valid_date?/3` answers `false` there, so its date callbacks and Localize return errors for such a date, but `months_in_year/1` and `days_in_month/2` raise `Calendrical.UnsupportedDateRangeError`, and so does converting a date outside the range into it, so `Localize.Date.parse("0001-001", calendar: Calendrical.Persian)` raises as it does for the Umm al-Qura calendar (above). Answer those callbacks, or reject the year, without raising.

* [ ] **Eras around 1 January AD 1 in `Calendrical.NRF` and `Calendrical.Reform.Sweden.Transitional`** — `day_of_era/3` takes the Gregorian date's era and `year_of_era/3` the calendar year's, so they disagree on NRF's fiscal year 0 days in AD 1 and on the Swedish calendar's first days of AD 1, which are Gregorian 1 BC.

* [ ] **`Calendrical.Reform.Sweden.Transitional` before AD 1** — its `plus/6` reaches a year 0 it does not have (`plus(-2, 6, 3, :years, 2)` is `{0, 6, 3}`), its `diff/3` counts two years from 3 June 2 BC to 3 June 1 BC, and `valid_date?(-1, 12, 8)` is false for a date `Date.convert/2` gives it (ISO 0000-12-06), so Localize's relative time there is wrong or an error (6,069 of 24,720 checks by days). Outside 1700 to 1712 the calendar is the Julian calendar and could pass these to it.

* [ ] **A calendar of weeks' `days_in_month/2` counts a period, not the month field** — `Calendrical.ISOWeek.days_in_month(2026, 25)` is 28, the days of a four-week period, though a week date's month field is its week, so `Date.days_in_month(~D[2026-W25-2 Calendrical.ISOWeek])` is 28 and `Date.end_of_month/1` gives 2026-W25-28, which is no date of the calendar. Elixir's `Date` functions read the month field: answer seven there, or decide what the two should mean in a calendar of weeks.

* [ ] **`extended_year/3` of a year BC in the Julian calendars** — TR35's extended year counts 1 BCE as year 0, but `Calendrical.Julian.extended_year(-1, 1, 1)` is -1, the calendar year as given, as it is in the new-year variants. Localize's `u` does not ask for it yet (Localize's `TODO.md`).

* [ ] **Delegate `Calendrical.TimeZone.resolve/3` to Localize** — Localize now parses and resolves a zone in every form a locale writes (`Localize.DateTime.Timezone.parse_zone/2` and `resolve/3`) and no longer calls this module, which duplicates it with a table of abbreviations and resolves a fall-back hour to daylight time where ICU and Localize take standard.

## Done

* [x] **`interval/3` and `interval_stream/3` order dates by their days** — they took the earlier of their two dates from `Date.compare/2`, which orders two dates of one calendar by their fields and never asks the calendar, so in the Julian new-year calendars, where 1 January follows 31 December of the same year, a run across January was wrong. Localize's relative time, durations and parsed ranges order dates the same way, held to these calendars by `test/localize_periods_test.exs`. 2026-10-02, v1.4.0.

* [x] **The parse callbacks answer every text, and a week date reads back** — `parse_date/1`, `parse_naive_datetime/1` and `parse_utc_datetime/1` answer malformed text with `{:error, :invalid_format}` in every calendar (11,648 malformed inputs across 32 calendars), where letters raised `ArgumentError`, a negative year is checked as itself, and a calendar of weeks writes "0004-W09-7" for year 4. Asserted by the contract test. 2026-10-02, v1.4.0.

* [x] **A calendar of weeks names its months from CLDR's generic calendar** — its `cldr_calendar_type/0` is `:generic`, "M01" to "M12", since its months are the unnamed periods of its pattern of weeks, and its eras keep the Gregorian names (user, 2026-10-02). 2026-10-02, v1.4.0.

* [x] **A date callback answers only for a date its calendar has** — every calendar's date callbacks return `{:error, :invalid_date}` for a date its `valid_date?/3` rejects and a `Calendrical.MissingFieldsError` for one missing a field, through `Calendrical.Compiler.DateCheck` and asserted for every calendar by the contract test, where they raised or answered in up to 25 calendars. 2026-10-01, v1.4.0.

* [x] **A month calendar numbers a month's own weeks** — `week_of_month/3` with a first day of the week follows TR35's rule for a year in each month, where it laid the year's weeks over 4-4-5 periods and differed from that rule on about 30% of days in every such calendar. 2026-10-01, v1.4.0.

* [x] **Shifting brings the day into the month reached once** — `Date.shift/2` and `NaiveDateTime.shift/2` add years and months together, as `Calendar.ISO` (460,320 date and 73,440 date-time shifts agree) and Temporal's `NonISODateAdd` do, weeks and days as calendar days, and a week calendar's months place the day once. 2026-09-30, v1.4.0.

* [x] **Shifting by weeks and days, and a date by a time unit** — neither was a defect: a naive date-time has no daylight saving, so its day was always a calendar day, and `DateTime.shift/3` converting back at the offset before the shift is Elixir's, the same for `Calendar.ISO`; `Date.shift/2` rejects a time unit itself, and the callback raises as `Calendar.ISO.shift_date/4` does. 2026-09-30, no change.

* [x] **Era and year answers match CLDR 49 and ICU4C 78.3** — no calendar raises before its first era, and Coptic and Ethiopic eras, lunisolar cyclic years, the Julian new-year variants and composites answer as CLDR and ICU do. 2026-09-29, v1.4.0.
