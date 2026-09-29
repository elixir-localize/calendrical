# TODO

Calendrical's open work. Design documents live in `plans/`.

## Open

* [ ] **A composite calendar whose members differ in CLDR type** — every composite's `cldr_calendar_type/0` is `:gregorian`, so `Calendrical.Reform.Japan`'s lunisolar dates before 1873 take Gregorian month names ("February" for the second lunar month) and no leap-month pattern. Naming them from the calendar in effect needs Localize to ask for it, or such composites to be split: a decision to make.

* [ ] **Umm al-Qura years outside the official tables** — ICU4C 78.3 falls back to the civil calendar there, and `Calendrical.Islamic.UmmAlQura` begins some years a day earlier: 1 Muharram 1178 is 1764-06-30 here and 1764-07-01 in ICU (also 607, 717, 758 and 1261 AH). Find which fallback Calendrical uses and document or change it.

* [ ] **Eras around 1 January AD 1 in `Calendrical.NRF` and `Calendrical.Reform.Sweden.Transitional`** — `day_of_era/3` takes the Gregorian date's era and `year_of_era/3` the calendar year's, so they disagree on NRF's fiscal year 0 days in AD 1 and on the Swedish calendar's first days of AD 1, which are Gregorian 1 BC.

## Done

* [x] **Era and year answers match CLDR 49 and ICU4C 78.3** — no calendar raises before its first era, and Coptic and Ethiopic eras, lunisolar cyclic years, the Julian new-year variants and composites answer as CLDR and ICU do. 2026-09-29, v1.4.0.
