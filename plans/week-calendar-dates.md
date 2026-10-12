# The dates of a calendar of weeks

**Status:** implemented (v1.4.0), 2026-10-13

## The problem

A calendar of weeks (`Calendrical.ISOWeek`, `Calendrical.NRF`, one made with `Calendrical.new/3` and `:week`) held the week of the year in a date's month field and the day of the week in its day field: `Date.new(2026, 25, 2, Calendrical.NRF)` was the second day of week 25. Elixir's `Date` has no field for a week, so the month field carried it.

The calendar then answered questions of months in two meanings. `valid_date?/3`, `days_in_month/2` and `day_numbers/2` were about the field, a week: `days_in_month(2026, 6)` was 7. `months_in_year/1`, `month_numbers/1`, `month/2`, `month_of_year/3` and `plus/6` with `:months` were about the twelve months of the calendar's pattern of weeks: `month(2026, 12)` was weeks 49 to 52. A consumer that hands a calendar a year, a month and a day had to know which kind of calendar it held: `2026`, `12`, `2` named 20 April 2026 by the fields and 4 January 2027 by the calendar's own month. Tempo asked `calendar_base/0` at 80 places for that reason alone.

## The decision

The user, 2026-10-13: a month in a calendar of weeks is its own month. A date of one is a year, a month of its pattern of weeks (1 to 12) and a day of that month (1 to 28 or 35, and a week more in the last month of a year of 53 weeks), as `Date.new/4` takes a date of any calendar. The week is not a field: it is asked for and given through callbacks every calendar answers. It is not a new major version: the change brings the calendars into line with what `Date.new/4` means by a month.

## The shape

* **The arithmetic still counts in weeks** — `Calendrical.Base.Week` is built on a year of whole weeks, and its functions take a year, a week and a day of the week as they did. `Calendrical.Compiler.Week` turns a date into those on the way in (`Calendrical.Base.Week.week_date/4`) and an answer that is a date back on the way out (`month_date/4`).

* **What is asked of the fields is asked of months** — `valid_date?/3`, `days_in_month/2`, `days_in_month/1` (the last month is `{:ambiguous, [days, days + 7]}`), `day_numbers/2` and `month_numbers/1` by their defaults, and the dates of `year/1`, `quarter/2`, `month/2` and `week/2`.

* **The week goes by callbacks** — `week_of_year/3`, `week_of_month/3`, `week_date_from_date/3` and `date_from_week_date/3`, whose day is counted from the day the calendar's weeks begin on.

* **Text** — a date is written as its year, month and day, `2026-06-16`, as `Calendar.ISO` writes one. `parse_date/1`, and so the `~D` sigil, still reads a week date, `2026-W25-2`, as the date it names, which is how these calendars wrote their dates until 1.4. `parsing_calendar/0` stays `Calendar.ISO` (the user, 2026-10-13: "Week calendars don't have \"Feb\" that have \"M02\". So it needs to be the gregorian date converted"): Localize reads the calendar's own formats first, "M02 1, 2024 AD", and only what none of them reads in the calendar it names, so "Feb 1, 2024" is 1 February 2024 converted. It was the calendar itself in `80bdbf9`, which made that text an error.

* **`calendar_base/0` stays** — it says what a calendar's year is built of, and Calendrical's own calendar pages and its shift of years and months ask it. No consumer needs it to read a date.

## The proof

Every answer about a day was written out before the change and after it, with each date an answer names written as its count of days so that the fields do not matter: 42,455 days and 135 years of five calendars (the two shipped and three made for the purpose, of the 4-4-5, 5-4-4 and 4-5-4 patterns, beginning and ending, on three weekdays). Per day: the day of the year and of the era, the week, month and quarter, the week of the month, the ISO week, the day of the week from four starts, the five notions of a year, the week date both ways, `plus/6` in five units by ten steps with and without coercion, four shifts and ten differences; per year: its weeks, days and months, and the dates of its year, quarters, quadrimesters, semesters, months and weeks. No answer differs.

## What it changes for a consumer

`Date.new(2026, 25, 2, Calendrical.NRF)` is an error, and the same day is `Date.new(2026, 6, 16, Calendrical.NRF)` or `Calendrical.NRF.date_from_week_date(2026, 25, 2)`. `date.month` is a month. `Date.days_in_month/1` and `Date.end_of_month/1` are a month's, where they were a week's. A date is written `2026-06-16`. The migration guide has the before and after.
