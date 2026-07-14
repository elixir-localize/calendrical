# Period calendars: bi-weekly pay and university/academic calendars

Status: planned, deferred until after Calendrical 1.0 (targeted for the end of July 2026, released together with Localize 1.0). Motivated by Tempo (`~/Development/tempo/tempo`), which consumes Calendrical calendars directly (`Tempo.new!(..., calendar: Calendrical.Hebrew)`) — any calendar implementing the `Calendar` + `Calendrical` behaviours plugs into Tempo's interval, iteration and set machinery with no Tempo-side changes.

## Architectural verdict

Both calendar styles are buildable today as **Behaviour calendars** (`use Calendrical.Behaviour` + `date_to_iso_days/3` + `date_from_iso_days/1` + targeted overrides). Neither fits the month/week **compilers**, whose configs assume 12 Gregorian-aligned months or 13-week quarters in the `[4,4,5]` family. See ARCHITECTURE.md for the parameterization-vs-implementation distinction this rests on.

Verified contract facts the design relies on: the stdlib types `Calendar.day/0`, `Calendar.month/0` and `Calendar.week/0` are all `pos_integer()` (no 1..31 day ceiling), so shapes like day 12 of period 26 or day 87 of Fall term are contract-clean; and `date_from_iso_days/1` must be total — every real day must map to a date — because `Date.convert/2` requires it.

## Phase 1 — bi-weekly pay calendar

Shape: `{year, period, day}` with period 1..26 (27 in drift years) and day 1..14. Structurally a week calendar with a 14-day week: periods anchor to a fixed payday weekday, 26 periods = 364 days, and the anchor drift produces occasional 27-period years — the same mechanics as the 52/53-week long year in `Calendrical.Base.Week`, reimplemented for a 14-day period on the Behaviour.

* `date_to_iso_days(y, p, d) = first_period_start(y) + (p - 1) * 14 + d - 1`; `first_period_start/1` anchors to the configured payday weekday via the `Calendrical.Kday` helpers.

* Overrides: `leap_year?/1` (27-period years), `days_in_month/2` (constant 14), `months_in_year/1` (26 or 27), `month/2` ranges; pass `days_in_week: 14` to the Behaviour.

* Effort comparable to `Calendrical.Buddhist` (~100 lines plus tests). Build this first: it is the smaller calendar and exercises the long-period mechanics the university calendar reuses.

## Phase 2 — university/academic calendar

Shape: year = academic year, month = term, day = day-of-term. Year anchoring ("begins the last Monday of August") uses the existing kday/anchor machinery.

* **Decided approach for gaps**: breaks get their own pseudo-terms (`months_in_year` enumerates Fall, Winter Break, Spring, Summer, ...). This keeps `date_from_iso_days/1` total and keeps term ranges and iteration truthful. The alternative (folding break days into the preceding term) was considered and rejected as less honest.

* Decide fixed algorithmic term boundaries vs table-driven per-year published dates. Real institutions publish dates that move; a table-driven Behaviour calendar (per-year lookup with an algorithmic fallback, the pattern used by the Composite compiler's transition tables) is the likely end state.

## Phase 3 (optional) — harness generalization to parameterizations

Only if Tempo needs families of these calendars (one config per institution or employer) rather than a handful of named modules. Two known-debt sites from the architecture review are the exact blockers:

* Generalize `Calendrical.Config.weeks_in_month` from the three 4-4-5 patterns to any list of positive week counts, removing the 13-week-quarter assumption from `Calendrical.Base.Week` (semesters then express as "months" of e.g. `[15, 2, 15, 2, 12, 5]` weeks including breaks).

* Lift the hardcoded `@days_in_week 7` in `Calendrical.Base.Week` into config (the Behaviour already parameterizes `days_in_week`; the week stack does not), making the fortnight calendar a week-compiler parameterization creatable at runtime via `Calendrical.new/3`.
