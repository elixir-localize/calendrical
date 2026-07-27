# Possible enhancement — epoch-anchored and labelled calendars

A design spec (review-and-decide, nothing committed) for two families of "human calendar" that Calendrical cannot currently express, surfaced while building custom-calendar support in Tempo (downstream).

## The gap

`Calendrical.new/3` builds calendars via `Calendrical.Base.Month` and `Calendrical.Base.Week`, both driven by the **year-anchored** `Calendrical.Config` — `month_of_year`, `weeks_in_month: [4,4,5]`, `day_of_week`, `year: :majority`, `min_days_in_first_week`. This cleanly covers:

* **Fiscal years** — a month calendar with a `month_of_year` start offset (`Calendrical.FiscalYear`).

* **ISO-week / 4-4-5 retail** — a week calendar with a `weeks_in_month` layout.

What it cannot express — verified: `new(_, :week, weeks_in_month: [2])` and an `epoch:`/`period_length:` config are both rejected:

* **Epoch-anchored cycles** — a fixed *N*-unit cycle counted from an epoch, with **no year to hang on**: 2-week **sprints** from a start date, **biweekly pay periods** (26/year is a consequence, not a structure).

* **Labelled / irregular periods** — **academic terms** (Fall/Spring/Summer) or **seasons** with bespoke, non-uniform boundaries.

The whole behaviour keys every period accessor by year — `month(year, month)`, `week(year, week)`, `periods_in_year(year)`, `weeks_in_year(year)`, `quarter(year, quarter)`. **A sprint has no year.** That mismatch is the core design problem, not a missing config field.

## The one thing that *is* calendar-agnostic

The behaviour's only year-free primitives are the pair every calendar must implement anyway:

```
date_to_iso_days(year, month | week, day, config) :: iso_days
date_from_iso_days(iso_days, config)              :: {year, month | week, day}
```

Everything downstream (including Tempo's calendar-independent comparison and duration, which route through `Date.convert/2` → `date_to_iso_days`) depends only on this pair being correct. So a new calendar family is viable **iff** its `{a, b, c}` coordinate can be defined and round-tripped through `iso_days` — even if the year/month/day *labels* are repurposed.

## Enhancement A — `Base.Periodic` (epoch-anchored cycles)

**Model.** A period is the *N*th cycle of fixed length from an epoch. Repurpose the coordinate as `{cycle, 1, day_in_cycle}` — `cycle` in the year slot (it is the only unbounded ordinal), a constant `1` in the period slot, `day_in_cycle` in the day slot.

**Config additions** (a `Periodic` config, or new `Config` fields guarded by `calendar_base: :periodic`):

* `epoch` — the anchor date (or its `iso_days`).

* `period_length` + `period_unit` (`:day` | `:week`) — e.g. `{2, :week}` for a sprint, `{14, :day}` for a pay period.

**Conversions** (the whole implementation, essentially):

```elixir
def date_to_iso_days(cycle, _one, day_in_cycle, %{epoch: e, days_per_cycle: n}),
  do: e + (cycle - 1) * n + (day_in_cycle - 1)

def date_from_iso_days(iso_days, %{epoch: e, days_per_cycle: n}) do
  offset = iso_days - e
  {div(offset, n) + 1, 1, rem(offset, n) + 1}
end
```

**`calendar_base()`** → a new `:periodic` value (alongside `:week` / `:month`). The year-keyed period accessors (`month/2`, `week/2`, `quarter/2`) either return `{:error, :not_defined}` or map to "cycle N" — a decision to make.

**Open questions.**

1. **Labelling.** Is `cycle` in the `year` slot acceptable, or does `:periodic` warrant its own coordinate names? The former reuses all plumbing (Date, `iso_days`, downstream calendar-independence) at the cost of `~D[42-01-15 SprintCalendar]` reading oddly. Recommend: reuse the slot, document it.

2. **Iteration unit.** `periods_in_year/1` is meaningless here; iteration should step by cycle or by day-in-cycle. Define what "iterate cycle 42" yields.

3. **Where the epoch lives.** Per-calendar config (one sprint cadence per module) is simplest; a runtime epoch is more flexible but breaks the "calendar is a module" model.

**Effort.** Small — the two conversion functions plus a `:periodic` base and config validation. It reuses the existing `iso_days` plumbing entirely.

## Enhancement B — `Base.Labelled` (irregular named periods)

**Model.** A calendar whose periods are an explicit, possibly repeating list of `{label, start, end}` spans — academic terms, seasons, legislative sessions. Coordinate: `{cycle_year, term_index, day_in_term}`.

**Config.** A `terms` list (each with a label and a start rule — a fixed month/day, or an *N*th-weekday rule via `Calendrical.Kday`), and a repeat cadence (usually annual). Boundaries need not tile the year (there may be gaps — summer break).

**Harder than A** because periods are non-uniform (so `date_from_iso_days` is a search over the term table for the year) and may not cover the year. Worth its own design pass once A lands; sketch only here.

## Does this even belong in Calendrical?

The honest alternative: epoch-cycles and labelled periods are **granularities, not calendars** — they lack the year/month/day ontology the `Calendar` behaviour assumes, and forcing them in (Enhancement A's `cycle`-in-`year` slot) is a repurposing. Two paths:

* **In Calendrical (recommended for A).** A `:periodic` base is a thin, well-contained addition, and it buys the whole ecosystem — `Date`, `Date.convert/2`, `strftime`, and Tempo's calendar-independent operations — for free, because they bottom out at `date_to_iso_days`. The labelling awkwardness is cosmetic.

* **A separate lightweight abstraction.** A `%Periodicity{epoch, period}` struct with just `period_of(date)`, `boundaries(n)`, `nth(n, within)` — cleaner ontology, but it forgoes the `Date`/`Calendar` ecosystem and would need its own downstream plumbing in every consumer. Reasonable for B (labelled) where the "calendar" fit is weakest.

Recommendation: **A as a `:periodic` calendar in Calendrical** (small, high-leverage, reuses everything); **B deferred**, and revisited as either `Base.Labelled` or a separate periodicity type after A ships and a concrete need appears.

## Downstream (Tempo) impact

None required for A beyond consuming it. Tempo already routes comparison, duration, iteration, and materialisation through the calendar (calendar-independence work, 2026-07), so a correct `Base.Periodic.date_to_iso_days/4` makes sprint/pay-period values compare cross-calendar and materialise correctly with **no Tempo change**. Tempo's optional period-query conveniences (`enclosing/2`, `nth/3`) would then light up for periodic calendars too.

## References

* `lib/calendrical/config.ex` — the year-anchored config surface.
* `lib/calendrical/base/{month,week}.ex` — the builder pattern and the `date_to/from_iso_days` contract to mirror.
* `lib/calendrical.ex` — the `Calendar` + `Calendrical` behaviour (`@callback` list) an implementation must satisfy.
* Tempo `guides/custom-calendars.md` and `plans/user-defined-granularities.md` — the downstream consumer and the granularity framing.
