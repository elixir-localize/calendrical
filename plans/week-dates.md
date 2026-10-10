# Week dates in a calendar's own year

**Status:** draft, 2026-10-10

For discussion. The user, 2026-10-10, after choosing "the calendar's own year" from a question put to them, and before the work was committed: "We will go back and discuss week dates (iso or calendar) later." Nothing of this is in the library: the implementation below was built, tested and taken out again, and is kept as a patch.

## The question

A week date names a day by a year, a week of it and a day of the week. Two things in the three libraries answer for one, and they differ outside the Gregorian calendar.

* **`iso_week_of_year/3`, in Calendrical** — the week of the Gregorian year a day is in, whichever calendar names the day. Its documentation says so, and `Calendrical.Base.Common.iso_week_of_year/4` converts the date to the Gregorian calendar and asks it. `Calendrical.Hebrew.iso_week_of_year(5786, 3, 4)` is `{2025, 48}`.

* **A week written in a value, in Tempo** — `5786W10[u-ca=hebrew]` is week 10 by ISO 8601's rule over the Hebrew year: a week begins on Monday, and week 1 is the week that holds the year's fourth day. It is RFC 7529's reading of `BYWEEKNO` beside `RSCALE`. Its Monday is 4 Kislev 5786, which is 24 November 2025. Tempo works it out itself (`Tempo.UnitValues.date_from_iso_week/4`, `iso_weeks_in_year/2`), with `Calendrical.ISOWeek` named for the Gregorian calendar as a fast path.

* **A calendar's own weeks** — `week_of_year/3` and `week/2` follow the calendar's week configuration (its first day, the fewest days of its first week), which is neither of the two above in a calendar that is not configured as ISO 8601's.

So "the ISO week" of a Hebrew date is the Gregorian's in Calendrical and the Hebrew year's in Tempo, and Tempo can turn a week date into a date in any calendar of months but a date into a week date only in the Gregorian calendar and in a calendar of weeks (`Tempo.Enumeration.Zone.in_calendar_of/2`).

## What is to be decided

* **Which year an ISO-style week of a calendar of months is of** — the calendar's own, as Tempo and RFC 7529 have it, or the Gregorian's, as `iso_week_of_year/3` has it, in which case a week date written in another calendar of months is refused.

* **Whether a week date in a calendar of months other than the Gregorian is wanted at all**, outside a rule with `RSCALE`.

* **What a calendar of weeks answers** — its own dates, which are a year, a week and a day of the week already, with the day counted from the calendar's own first day of the week (Sunday in `Calendrical.NRF`), where ISO 8601 counts from Monday.

* **The names**, if callbacks are added.

## The implementation that was built

Three required callbacks, each with a default every calendar has from `Calendrical.Compiler.StandardCallbacks`, the logic in a plain module, `Calendrical.Base.WeekDate`:

* **`date_from_week_date/3`** — the date of a week-year, a week and a day of the week (1, Monday, to 7), or `{:error, :invalid_date}`.

* **`week_date_from_date/3`** — the week-year, the week and the day of the week of a date.

* **`weeks_in_week_year/1`** — how many weeks a week-year has.

A year's week 1 begins on the Monday on or before its fourth day (`Calendrical.Base.Common.year_days/2`, `Calendrical.Kday.kday_on_or_before/2`), and the rest is counting in days. A calendar of weeks overrides the three with its own date fields. `iso_week_of_year/3` is not changed.

Measured with it in the tree: the Gregorian calendar's week date of every day from 25 December 2019 to 7 January 2028 is that of Erlang's `:calendar.iso_week_number/1` with Elixir's `Date.day_of_week/1`, and its weeks in each year from 1990 to 2050 are the week 28 December is in; every date of two years in the Hebrew, Persian, Coptic, `Julian.March25` and `Reform.England` (1751 to 1753) calendars has one week date, which names it; week 1 holds the fourth day of each of 43 years in three calendars, and the day before it is day 7 of the last week of the year before. Ten tests, all passing.

The patch is in the checkout's ignored `tmp/week_dates/`: `tracked.patch` (the three files changed), `week_date.ex` (the module) and `week_date_test.exs` (the tests). Localize's `Localize.Calendar.ISO` would answer the three as well, which was not written.

## Tasks

* [ ] **Decide with the user** — the four points above.
