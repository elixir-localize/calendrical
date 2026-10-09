# Plan: Tempo TODO items and callback-surface review

Status: Part 1 implemented 2026-10-09 (items 1-5 in the working tree; item 6 handed to Localize's TODO). Part 2, the callback-surface restructure, and the Tempo hand-offs of Phase D remain open. Written 2026-10-09 against `81c022a`.

This plan covers the six Open items Tempo logged in [TODO.md](../TODO.md) and a review of the Calendrical behaviour's 28 `@callback`s. The review is grounded in a three-consumer dispatch survey: every call Tempo makes into a calendar module, every call Localize makes (probes, direct calls, and its `ask/5` dispatcher), and every polymorphic dispatch inside Calendrical's own `lib/`. Conformance with the Elixir `Calendar` behaviour is a firm requirement throughout.

## Evidence summary

Three consumers were mapped. The headline findings:

* **Localize's `@answers` list (`localize/lib/localize/calendar.ex:1624-1642`) is the de-facto external contract.** It validates 16 Calendrical callbacks plus the Elixir `Calendar` callbacks before accepting a calendar: `cldr_calendar_type/0`, `era_calendar_type/0`, `parsing_calendar/0`, `month_of_year/3`, `cardinal_month/1`, `calendar_year/3`, `extended_year/3`, `related_gregorian_year/3`, `cyclic_year/3`, `week_of_year/3`, `week_of_month/3`, `week/2`, `quarter/2`, `year/1`, `plus/6`, `diff/3`.

* **Tempo hard-depends (no probe, no fallback) on**: `days_in_month/1`, `days_in_year/1`, `weeks_in_year/1`, `iso_week_of_year/3`, `calendar_base/0`, `plus`, and — critically — three functions that are not declared `@callback`s at all: `days_in_week/0`, `date_to_iso_days/3`, `date_from_iso_days/1`. It probes `months_in_year/0` and `cldr_calendar_type/0`.

* **Three declared callbacks are dispatched by nobody anywhere** (not Tempo, not Localize, not Calendrical internally): `quadrimester/2`, `semester/2` are reached only from `Calendrical.Interval` and can be computed there; `periods_in_year/1` is self-dispatch only (a calendar passing itself to shared helpers); `dates_in_gregorian_year/3` has no polymorphic dispatch at all — each implementation calls the generic, and the generic never calls back, so the `defoverridable` added in the 1.4.0 review is currently unreachable from the public entry point.

* **A family of undeclared, probed functions forms a shadow protocol**: `months_in_leap_year/0` (probed at `format.ex:165`), the lunisolar trio `ordinal_month_from_traditional/2` / `leap_month/1` / `traditional_leap_month/1` (probed at `period.ex:91-92`), `parsing_calendars/0` and `calendar_from_cldr_calendar_type/1` (probed by Localize), plus the composite-internal set (`year_bounds/1`, `calendar_for_iso_days/1`, `shift_months/5`, `reach/5`, `__config__/0`, `iso_days/3`).

* **One latent crash**: `Interval.day/3` (`interval.ex:359`) calls `first_gregorian_day_of_year/1` unprobed, but only month- and week-compiler calendars define it. Calling `Interval.day/3` with a Julian, lunisolar, or composite calendar raises `UndefinedFunctionError`.

## Part 1 — the six TODO items

### Items 1–3 are one defect: named month fields on year-shifted Julian variants

`Julian.March25` (and `March1`, `Sept1`, `Dec25`) keep *named* month fields — March is 3, January is 1 — while the year begins mid-sequence. Field order therefore disagrees with time order, and since Elixir's `Date.compare/2` compares same-calendar dates as `{year, month, day}` tuples, comparison is genuinely wrong, not merely surprising (Tempo confirmed on `2d4dbc6`). That single choice produces all three items: the England composite's pre-1751 months not covering 25–31 March (item 1), month 3 holding two spans 364 days apart with no time-ordered accessor (item 2), and `days_in_month` answering named lengths while `month/2` enumerates counted spans (item 3).

**Recommendation: re-field the year-shifted Julian variants to counted months**, the same convention the fiscal month-compiler calendars already use. Field order then equals time order, and `Date.compare/2`, `Date.beginning_of_month/1`, `Date.end_of_month/1`, and `days_in_month/2` are all conformant by construction.

Design points:

* Counted months partition the year exactly as `month/2` already enumerates them. Whole-month variants (`March1`, `Sept1`) get 12 counted months that are whole named months remapped (counted 1 = March for `March1`). Split variants (`March25`, `Dec25`) get 13 counted months: for `March25`, counted 1 = 25–31 March (7 days), counted 2 = April, …, counted 13 = 1–24 March.

* `cardinal_month/1` maps counted → named for localization, exactly as fiscal calendars do. For split variants, counted 1 and 13 both map to named 3; both display as March.

* The day field is the position within the counted month, so for `March25` the date historians write as 25 March 1750 has fields `{1750, 1, 1}`. Formatting and parsing must therefore surface the *named* day as well as the named month. `month_of_year/3` already answers the named month; the plan adds the named day to that story — either extend what `month_of_year/3` returns for these calendars or add one optional callback (working name `named_month_and_day/3`) that Localize's formatter and parser consult. This is the one open design decision in Part 1; settle it at implementation time with a doctest-driven round-trip (`parse("25 March 1750")` → fields → format → "25 March 1750").

* Item 1 then resolves for free: the England composite's pre-1751 segment delegates to `March25`, whose counted months now partition the whole year including 25–31 March.

* Item 2's accessor: add `Calendrical.named_month(calendar, year, named_month) :: [Date.Range.t()]`, time-ordered, computed from `month/2` plus the counted→named mapping. A plain function, not a callback.

* Item 3 resolves: `days_in_month/2` (Elixir callback) answers the counted month's true length (7 for `March25` month 1), and `days_in_month/1` continues to answer the maximum (31).

**Release placement**: `March25` and siblings shipped in 1.3.0 with named fields, so this is a breaking change for published behaviour. The precedent is the 1.3.0 week-start corrections — conformance defects are bug fixes even when behaviour changes — and 1.4.0 already carries the documented `:begins_or_ends` break. Recommend landing in 1.4.0 with a prominent Changed entry; the alternative is deferring to 2.0, which leaves `Date.compare/2` broken on four published calendars for the whole 1.x line.

### Item 4 — enumerate a lunisolar year's traditional months

First try the zero-callback route: `Calendrical.traditional_months(calendar, year)` iterating ordinal months `1..months_in_year(year)` and asking `month_of_year(year, ordinal, 1)` for each one's traditional number and leap flag, returning `[{traditional_month, leap? :: boolean}]` in time order. If `month_of_year/3`'s current returns carry both facts for the five lunisolar calendars, item 4 is a plain function. Independently, declare the already-probed trio (`ordinal_month_from_traditional/2`, `leap_month/1`, `traditional_leap_month/1`) as optional callbacks (Part 2), which also gives Tempo what it needs for jscalendar "3L" month identifiers.

### Item 5 — month-week geometry

Tempo brute-forces nth-week-of-month at 48–310 µs/month. Add to `Calendrical.Interval`, computed from the existing surface (no new callbacks): `Interval.weeks_in_month(year, month, calendar_with_options)` and an `Interval.week/4` (nth week of a month, as a `Date.Range`), derived from `month/2`, `days_in_week/0`, `day_of_week/4`, and the same week-definition options `week_of_month/3` already honors. Property-test against `week_of_month/3` as the oracle: every day in the returned range reports that month-week number.

### Item 6 — `Calendrical.parse/2` quadratic on long strings

`parse.ex` delegates to Elixir `parse_date/1`/`parse_time/1`, whose combinators come from the Localize-generated parsing layer, so the superlinearity almost certainly lives in Localize. Two actions: in Calendrical, add a cheap input-length guard (a date/time string beyond a small bound cannot be valid — reject before parsing, documented); and hand the quadratic itself to a Localize session (Localize review is out of scope here by your earlier direction). Record it in Localize's TODO with Tempo's measurement (570 ms at 8 KB).

## Part 2 — callback-surface restructure

The surface's problem is less its size than its honesty: three declared callbacks carry no dispatch while three undeclared functions are hard requirements of the library's main consumer. The restructure trues the declarations up to the evidence and organizes the result into documented tiers. The authoring burden does not grow: `use Calendrical.Behaviour` already requires `date_to_iso_days/3` and `date_from_iso_days/1` and defaults everything else, and that stays so.

### Demote (remove `@callback`, keep the functionality)

* `quadrimester/2` and `semester/2` — dispatched only by `Interval`; compute them there from `month/2` (semester = periods 1–6 / 7–12, quadrimester = thirds), which is correct for month, fiscal, and week calendars alike since `month/2` already answers each calendar's own period geometry. Keep `Calendrical.Interval.semester/…` public API unchanged.

* `periods_in_year/1` — self-dispatch only, reached from the month/week compilers' `plus … :years` path; make it part of the compiler-internal contract, not the public behaviour.

* `dates_in_gregorian_year/3` stays a callback, but fix the inconsistency: the public generic must dispatch through the callback so the `defoverridable` added in the 1.4.0 review actually takes effect.

### Promote to required `@callback` (already universally implemented, already hard-dispatched)

* `days_in_week/0` — Tempo calls it unconditionally; Calendrical itself calls it unprobed at `format.ex:246`, `composite/diff.ex:34`, `base/common.ex:258`. Every calendar already defines it.

* `date_to_iso_days/3` and `date_from_iso_days/1` — the round-trip spine; `use Calendrical.Behaviour` already refuses to compile without them, and Tempo calls both by name.

### Declare as optional `@callback`s (formalize the shadow protocol)

* `months_in_leap_year/0` (probed at `format.ex:165`).

* `ordinal_month_from_traditional/2`, `leap_month/1`, `traditional_leap_month/1` (probed at `period.ex:91-92`; wanted by Tempo for "3L").

* `parsing_calendars/0` (probed by Localize at `calendar.ex:1718`; defined by composites).

* `calendar_from_cldr_calendar_type/1` (probed by Localize at `calendar.ex:1875-1877`; every calendar defdelegates it).

The composite/compiler-internal set (`year_bounds/1`, `calendar_for_iso_days/1`, `shift_months/5`, `reach/5`, `iso_days/3`, `__config__/0`, `first_day_of_year/1`, `date_from_julian_date/3`) stays undeclared but gets a short "Internal calendar protocol" moduledoc section stating these are Calendrical-internal and not for external dispatch.

### Resulting shape

26 required callbacks (23 kept + 3 promoted), 8 optional (`months_in_year/0`, `cldr_calendar_type/3`, plus the six newly declared), organized in the moduledoc into capability groups: identity (`cldr_calendar_type`, `era_calendar_type`, `calendar_base`, `parsing_calendar`), year notions (`calendar_year`, `extended_year`, `related_gregorian_year`, `cyclic_year`), geometry (`days_in_*`, `weeks_in_year`, `months_in_*`, `year/1`, `quarter/2`, `month/2`, `week/2`), weeks (`week_of_year`, `iso_week_of_year`, `week_of_month`, `days_in_week`), months (`month_of_year`, `cardinal_month`), arithmetic (`plus/6`, `diff/3`, `date_to_iso_days`, `date_from_iso_days`), and lunisolar (the optional trio). Document Localize's `@answers` validation as the external contract it is.

### Fixes that fall out of the survey

* `Interval.day/3` crash: give `first_gregorian_day_of_year/1` a `Calendrical.Behaviour` default (first day of `year/1` through `date_to_iso_days/3`) so every calendar answers it, or rewrite `Interval.day/3` to not need it. Add a test driving `Interval.day/3` across one calendar of each family.

* `format.ex:246` calls `days_in_week/0` unprobed while `format.ex:287` probes it — consistent once it is a required callback; drop the probe.

## Hand-offs (not this repo's work)

* **Tempo**: `rounding.ex:42` does `div(calendar.weeks_in_year(year), 2)` but `weeks_in_year/1` returns a tuple — latent `ArithmeticError`; `mask.ex:179` calls `months_in_year/0` unprobed while other sites probe it; `iso_week_of_year/3` results are destructured without error handling; jscalendar "3L" unblocks once the lunisolar trio is declared and item 4 ships.

* **Localize** (separate session per your direction): the quadratic parse (item 6, 570 ms at 8 KB); stale comment at `datetime/formatter.ex:1170` claiming `related_gregorian_year/3` is probed when `:1181` calls it unconditionally.

## Sequencing

1. **Phase A — surface honesty** (non-breaking): promote/demote/declare per Part 2, fix the `Interval.day/3` crash and the `dates_in_gregorian_year/3` dispatch, regroup the moduledoc. All six gates after each step.

2. **Phase B — items 4 and 5** (additive): `traditional_months/2`, `named_month/3`, `Interval.weeks_in_month` + nth-week. Doctests and property tests against existing oracles.

3. **Phase C — items 1–3** (breaking for the year-shifted Julian variants): counted-month re-fielding, the named-day formatting/parsing decision, England composite verification, migration notes in the changelog.

4. **Phase D — hand-offs**: file the Tempo findings in Tempo's TODO, the Localize findings in Localize's TODO.

All of A–C target 1.4.0 (still blocked on Localize 1.4 / CLDR 49, expected 2026-10-16), with Phase C's breaking change called out at the top of the changelog. If you prefer Phase C in a 2.0 instead, phases A and B are unaffected.
