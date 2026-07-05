# Calendrical Architecture — the calendar harness

This document describes how Calendrical's calendars are constructed: the `Calendrical.Behaviour` macro, the month and week compilers, the runtime calendar-creation path, and the conventions that hold the system together. It is a maintainer document; the user-facing guide for defining calendars is [guides/calendar_behaviour.md](guides/calendar_behaviour.md). Line references are indicative and drift with edits; function names are the stable anchors.

## The four construction mechanisms

Every calendar module in Calendrical is built by exactly one of four mechanisms:

| Mechanism | Entry point | Calendars | Extension model |
|---|---|---|---|
| Behaviour template | `use Calendrical.Behaviour` | Gregorian, Coptic, Ethiopic (+ AmeteAlem), Buddhist, Indian, Persian, ROC, Hebrew, Islamic variants, Chinese, Korean, LunarJapanese | Open: every generated function is `defoverridable`; the module supplies `date_to_iso_days/3` and `date_from_iso_days/1` and overrides what it needs |
| Month compiler | `use Calendrical.Base.Month` → `@before_compile Calendrical.Compiler.Month` | Calendrical.Gregorian, Calendrical.ISO, fiscal/territory month calendars created at runtime | Closed: behaviour is driven entirely by the `%Calendrical.Config{}` captured at compile time; no `defoverridable` |
| Week compiler | `use Calendrical.Base.Week` → `@before_compile Calendrical.Compiler.Week` | Calendrical.ISOWeek, Calendrical.NRF, fiscal/territory week calendars created at runtime | Closed, as for the month compiler |
| Specialised compilers | `Calendrical.Julian.Compiler`, `Calendrical.Composite.Compiler` | Julian year-start variants (March1, March25, Sept1, Dec25), composite (era-switching) calendars | Closed: generated delegation with variant-specific normalization |

The lunisolar calendars are Behaviour calendars that delegate their conversion mathematics to `Calendrical.Lunisolar` (parametrized by epoch and an observation-location function), the same way Coptic and Ethiopic delegate to `Calendrical.Base.Egyptian`.

## The Behaviour template

`Calendrical.Behaviour.__using__/1` accepts `:epoch` (mandatory), `:cldr_calendar_type`, `:cldr_calendar_base`, `:days_in_week`, `:first_day_of_week`, `:months_in_ordinary_year` and `:months_in_leap_year`. It sets `@behaviour Calendar` and `@behaviour Calendrical`, stores the options as module attributes, and generates roughly 48 functions in one quoted block: identity accessors, validity checks, year/era functions, period queries, counts, `Date.Range` builders, arithmetic (`plus`, `shift_*`), iso-days conversion plumbing, and parse/format delegates. Everything generated is `defoverridable`.

Two functions are deliberately not generated and must be supplied by the using module: `date_to_iso_days/3` and `date_from_iso_days/1`. They are the only calendar-specific mathematics the template needs; every default implementation is written against them.

Defaults are conservative: `week_of_year/3`, `weeks_in_year/1` and `week/2` return `{:error, :not_defined}` (weeks are a localized concept the template cannot guess), `days_in_month/1` without a year returns `{:error, :undefined}` when month lengths vary, and `months_in_year/0` returns `{:ambiguous, first..last}` for calendars with leap months. `related_gregorian_year/3` computes the Gregorian year containing the calendar year's first day, which is generically correct for every calendar built on the template.

The `Calendrical` behaviour contract itself (the `@callback` declarations) lives in `lib/calendrical.ex`, with `months_in_year/0` and `era_calendar_type/0` declared `@optional_callbacks`.

## The month and week compiler stacks

The compiled stacks have three layers with a strict division of labour:

1. **`use Calendrical.Base.{Month,Week}`** stores the options in `@options` and registers the compiler as a `@before_compile` hook. That is all it does at `use` time.

2. **`Calendrical.Compiler.{Month,Week}.__before_compile__/1`** runs `Calendrical.Config.extract_options/1` and `validate_config!/2` at compile time, stores the validated `%Config{}` as `@calendar_config`, and emits a `quote location: :keep` block of ~65 thin delegates. Each delegate passes `__config__()` (the compile-time config snapshot) as the final argument to the runtime base. A handful of time-of-day functions delegate straight to `Calendar.ISO`.

3. **`Calendrical.Base.{Month,Week}`** contains all real logic as plain runtime functions taking the `%Config{}` as their last parameter. Config is read-only; nothing mutates or caches it.

The consequence for navigation: to find the implementation of `Calendrical.Gregorian.week_of_year/3` you traverse gregorian.ex (`use` line) → base/month.ex (`__using__`) → compiler/month.ex (the delegate) → base/month.ex (the logic). Four hops, two of them macro-mediated. This is the price of the design; the compensation is that the runtime logic is ordinary, testable, breakpointable code rather than quoted AST.

`%Calendrical.Config{}` fields: `calendar`, `cldr_calendar_type`, `weeks_in_month` (the 4-4-5 family), `begins_or_ends`, `first_or_last`, `day_of_week` (1..7 or `:first`), `month_of_year`, `year` (`:majority`/`:beginning`/`:ending`), `min_days_in_first_week`. Validation happens once, at compile time (or at `Calendrical.new/3` time for runtime calendars); the base modules assume a valid config throughout.

## Data conventions (read before touching anything)

* **Week calendars store the week number in the `%Date{}` struct's `:month` field.** A `~D[2026-W05-3 Calendrical.ISOWeek]` date is `%Date{year: 2026, month: 5, day: 3}`. This is why `Calendrical.Base.Week`'s map defguard checks `:month`, why several week functions name their second parameter `month`, and why the two base modules can share `Date`-facing plumbing. It is a deliberate compatibility choice — the stdlib `Date` struct has no `:week` field — but it is the single most surprising fact in the codebase.

* **`iso_days` is a bare integer day number** (proleptic Gregorian day count as used by `Calendar.ISO.date_to_iso_days/3`), except in the `naive_datetime_*` plumbing where it is the stdlib's `{days, day_fraction}` pair. Functions named `*_iso_days` operate on the integer form.

* **Lunisolar calendars have two month numberings.** `Date` structs carry ordinal months (1..13, leap month folded into the sequence); the traditional form (1..12 with `{n, :leap}` for the intercalary) is accepted only by each calendar's `new/3`. The moduledocs of Chinese, Korean and LunarJapanese document the mapping; mixing the conventions is the classic off-by-one source after a leap month.

* **Era data is runtime-resolved.** `Calendrical.Era` reads CLDR era data on first use and caches it in `:persistent_term`; calendars reach it through the generated `year_of_era/3` and the optional `era_calendar_type/0` callback (used by LunarJapanese to borrow the Japanese era table while keeping `cldr_calendar_type/0` as `:chinese`).

## Runtime calendar creation

`Calendrical.new/3` (and `Calendrical.FiscalYear.calendar_for/1`, `calendar_from_territory/1`) create month/week calendars at runtime. The path is: check `Code.ensure_loaded?/1` for idempotency, then `Calendrical.Compiler.create_calendar/3`, which validates the config and sends the quoted `use Calendrical.Base.<Type>` form to the `Calendrical.Compiler` GenServer. The GenServer serializes all module creation (one `Module.create/3` at a time) and re-checks `Code.ensure_loaded?/1` inside `handle_call`, so concurrent creation of the same module is race-free: the first caller compiles, later callers get `{:ok, module}` from the recheck.

Two properties of this path to be aware of: module names come from `Module.concat/2` on validated input (territory codes are checked against the CLDR territory list before an atom is created), and each creation macro-expands the full compiler quote block at runtime, so creating a calendar costs a visible fraction of a second — callers should treat calendar modules as create-once values, which the idempotency check encourages.

## Known debt and invariants

* `behaviour.ex` generates from eleven per-concern quoted sections (prelude, identity/validity, eras, periods, shifts, counts, ranges, arithmetic, conversion, parse/format, overridable declarations) concatenated in order by `__using__` — the order matters because later sections read the prelude's attributes and the overridable declarations must follow every definition, and imports are lexical to each section's own quote. The month/week compiler modules still generate from single large quoted blocks; `.credo.exs` documents the exclusions (Credo measures quoted AST as if it were the enclosing function's complexity).

* `Calendrical.Base.Month` and `Calendrical.Base.Week` are structurally parallel (roughly 27 shared function names). The verbatim-identical pieces — the era-year mapping, `days_in_week`, the date guards — live in `Calendrical.Base.Common`; everything else that shares a name differs in substance because month arithmetic and week arithmetic genuinely differ, and further merging would obscure rather than deduplicate. Keep new shared logic in `Base.Common`; keep unit-specific logic in the respective base.

* Multi-month arithmetic on week calendars is O(n): `Calendrical.Base.Week.plus/7` adds months one at a time because leap-week accounting across long years has no closed form in the current implementation. The limitation is commented at the site.

* Week-53 handling in the week base is special-cased at each site that maps weeks to months or quarters (`month_of_year`, `month_in_quarter`, `quarter_of_year`, `days_in_month`, `maybe_extra_week_for_long_year`) rather than centralized.

* Compiled (month/week) calendars cannot override generated functions — configuration is their only extension point. Behaviour calendars are the opposite: everything is overridable. This asymmetry is intentional: a compiled calendar is a *parameterization*, a Behaviour calendar is an *implementation*.
