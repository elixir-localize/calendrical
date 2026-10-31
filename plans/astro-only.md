# Astro as the only source of astronomy

**Status:** in progress, 2026-10-31

From Astro 2.10, Calendrical computes no astronomy of its own: Astro answers every astronomical question, and Calendrical keeps the calendar rules. This also removes everything that existed to work around Astro 2.9, which answered only within the JPL ephemeris (1900–2100 for the bundled kernel) and only computed equinoxes for 1000–3000. The Astro functions this needs are planned in Astro's `plans/calendar-support.md`.

## What stays

The rules: a lunisolar month without a major solar term is the leap month; the year starts at the second new moon after the winter solstice; the solar term numbering; the Persian year starts on the day of the March equinox in Tehran, or the next if the equinox is after true noon; astronomical Easter is the Sunday after the first full moon after the March equinox; an Umm al-Qura month starts after conjunction if the Moon sets after the Sun at Mecca; an observational month starts the day after a visible crescent; day starts. Arithmetic calendars built on mean motions (Hebrew molad arithmetic, the Gregorian and Julian computus, ICU's arithmetic Persian years) are rules too.

## What moves to Astro

* **Lunisolar** (`compiler/lunisolar.ex`) — `new_moon_before/2`, `new_moon_on_or_after/2` and their `standard_from_universal |> floor` (lines 1549, 1590); `solar_longitude_on_or_after/3` (1292); `december_solstice_on_or_before/2` and its day walk (1691), `next_december_solstice/2` (1777); the moment-to-day step in `find_solar_term/3` (1346); `midnight_in_location/2` (1663) and the longitude at local midnight in `current_major_solar_term/2` and `current_minor_solar_term/2` (1420, 1479), whose term numbering stays.

* **Islamic** — the crescent search in `islamic/visibility.ex` (`next_visible_crescent/4` and the search anchors, lines 93–101, 196–206, 262–273); the local date of a conjunction in `umm_al_qura/astronomical.ex` (+3 h, line 268; UTC date, line 232; `prior_new_moon_iso_days/1`, visibility 278); the centre-of-disk sunset built from `solar_elevation: 90.5667` (astronomical 428–442); the moment-level `MoonRiseSet.moonset/3` call (449–456), which `Astro.moonset/3` already answers.

* **`DayStart`** — sunset for the location's own day, through Astro's `:utc_offset`, which also fixes the defect below.

* **Hebrew** — the mean solar time offset from longitude (`resolve_location/1`, 192–204).

## What is deleted

* **The lunisolar range guard** — `@supported_gregorian_years -20_005..20_005` and `out_of_range/1` (lunisolar 140–147, 1545, 1586, 1601), and the `rescue Calendrical.UnsupportedDateRangeError` used as control flow in `kept_year_and_month/3` (886–887).

* **Ephemeris coverage** — `searchable/1`, `covered?/1`, `out_of_ephemeris/1`, `@search_before`, `@search_after` and the `covered?` guard in `month_start_on_or_before/3` (visibility 37–41, 77, 120–122, 179, 287–297); the `:not_found` clauses in `visibility.ex` (236), `day_start.ex` (78–91) and `base/astro.ex` (15–21); the `:jpl_ephemeris` messages in `UnsupportedDateRangeError` once nothing raises them.

* **The 1000..3000 label** — `base/astro.ex` line 8 maps Astro's `:year_out_of_range` to `1000..3000`; Astro now answers within 50,000 years of 2000.

* **Persian's ranges** — `@supported_gregorian_years 1900..2100` and `@astronomical_years 1279..1479` (persian 45, 49) and the error clause at 280–287, subject to the decision below.

* **The match-bang it exposes** — `{:ok, datetime} = Astro.date_time_new_moon_before(...)` at visibility 279 is shielded today only by the coverage guard; it needs a real error path for `{:error, :year_out_of_range}`.

## Defects found

* **`DayStart` takes the previous evening's sunset west of about 30°W.** It asks `Astro.sunset(location, local_date, time_zone: :utc)`, and Astro picks the sunset whose UTC date is `local_date`, which there is the evening before. In Los Angeles, `Calendrical.Hebrew.date_at(~U[2024-06-20 23:00:00Z], day_start: :sunset, location: la)` (16:00 local) is already the next day. Present in the released 2.2.0.

* **Comments and specs** — the lunisolar `location/1` specs say hours where the offsets are in days; `lunar_japanese.ex` 203–208 says 1889 and GMT+8 where the code switches to UTC+9 on 1888-01-01; `vietnamese.ex` 173 says local apparent time where it is mean; the "required to calculate sunset" comments in the lunisolar `location/1` functions describe coordinates that are never used.

## Tests that assert Astro 2.9's limits

`test/ecclesiastical_test.exs` 326–332, 351–354, 464–470; `test/unsupported_date_range_test.exs` 21–43, 53–99, 116–127; `test/hebrew_test.exs` 473–476; `test/islamic_observational_test.exs` 137–138; `test/exception_message_test.exs` 169–182; and, by premise, `test/year_cache_calendars_test.exs` 114–170. Two tests move with Astro 2.10's ΔT: the Chinese solar term 5 of −3000 (one day) and ICU's Persian 1469-12-30 (the March 2091 equinox is within about 10 s of true noon in Tehran).

## Decisions

* **2026-10-31 — Persian computes every year from the equinox**, within Astro's 50,000 years, rather than ICU's arithmetic outside 1900–2100. Because Astro is the one source of astronomy and one method has no seam; years outside 1900–2100 may then differ from ICU's arithmetic calendar.

* **2026-10-31 — The lunisolar calendars keep their ±20,000 Gregorian years.** ΔT alone is uncertain by days that far out, so a wider range would add little real meaning.

* **2026-10-31 — The 2091 Persian case and the −3000 solar term take Astro 2.10's answers**, with a comment in each test that seconds of ΔT decide it.

## Tasks

* [ ] **Astro's new functions** — see Astro's `plans/calendar-support.md`.

* [ ] **Islamic on Astro's crescent search and local days** — and delete the coverage code; fix the match-bang.

* [ ] **`DayStart` on `:utc_offset`** — with a test west of 30°W.

* [ ] **Persian, Ecclesiastical, Hebrew and `Base.Astro`** — Persian from the equinox for every year, `year_and_new_year/1`'s 33-year estimate replaced by the Gregorian year and `Astro.equinox/3`.

* [ ] **Tests, docs and guides** — remove the 2.9 assertions and the old ranges (`guides/calendar_summary.md` 13, 270), and depend on `{:astro, "~> 2.10"}`.

### Done

* [x] **Lunisolar on day-level searches** — new moons, the December solstice and solar terms from `Astro.Lunar.new_moon_day_*` and `Astro.Solar.solar_longitude_day_*`; the day-by-day solstice walk is gone; the ±20,005-year day guard stays as the calendars' supported range, and the `rescue` in `kept_year_and_month/3` is replaced by a clause for days inside ±20,000 years. The Chinese solar term of −3000 takes Astro 2.10's day. 2026-10-31.
