# Parsing dates, times, datetimes, and intervals

Calendrical provides locale-aware parsers for user-typed date and time strings. There's a unified entry point — `Calendrical.parse/2` — that figures out what shape the input has, plus four targeted parsers for when the shape is known:

* `Calendrical.Date.parse/2`
* `Calendrical.Time.parse/2`
* `Calendrical.DateTime.parse/2`
* `Calendrical.Date.parse_range/2`

This guide describes what each parser accepts, how Calendrical compares to Elixir's stdlib parsers, and what to expect for common wire formats.

## What Calendrical is and isn't

Calendrical's parsers are designed around **CLDR locale data**. They read the locale's preferred field order, month/day/era names, day-period names, and lenient-separator equivalence classes. That makes them ideal for parsing input typed by humans — form fields, chat commands, casual UI.

They are **not** wire-format parsers. RFC 2822, HTTP date (RFC 7231 / IMF-fixdate), and `asctime` are not in CLDR and Calendrical does not recognise them. For those formats, use a dedicated library or write a small parser of your own.

ISO 8601 *extended* format (which is also the RFC 3339 subset) **is** supported as a universal escape hatch — it works in every locale regardless of `:locale` or `:calendar` option.

## Quick reference: what parses

The table below shows which inputs each parser accepts, and which other Elixir tools accept the same input.

| Input | Calendrical | Stdlib `*.from_iso8601/1` | Notes |
|---|---|---|---|
| `2026-05-23` (ISO date) | ✅ Date | ✅ `Date` | RFC 3339 date |
| `2026-05-23T14:30:00` | ✅ NaiveDateTime | ✅ `NaiveDateTime` | RFC 3339 datetime |
| `2026-05-23T14:30:00Z` | ✅ DateTime (UTC) | ✅ `DateTime` | |
| `2026-05-23T14:30:00+10:00` | ✅ DateTime (offset) | ✅ `DateTime` | |
| `2026-05-23T14:30:00.123456Z` | ✅ DateTime (μs) | ✅ `DateTime` | Fractional seconds |
| `2026-05-23 14:30:00` (space sep) | ✅ NaiveDateTime | ✅ `NaiveDateTime` | Common in SQL/logs |
| `14:30:00` / `14:30` | ✅ Time | ✅ `Time` | ISO time |
| `20260523` (basic) | ✅ Date | ❌ | Calendrical-only; ISO 8601 basic format |
| `2026-143` (ordinal) | ✅ Date | ❌ | Calendrical-only; ISO 8601 ordinal date |
| `2026-W21-6` (week date) | ✅ Date | ❌ | Calendrical-only; ISO 8601 week date |
| `5/16/26` (en) | ✅ Date | ❌ | CLDR `:M/d/yy` for `:en` |
| `16.05.2026` (de) | ✅ Date | ❌ | CLDR `dd.MM.y` for `:de` |
| `民國115年5月16日` (zh-Hant-TW, ROC) | ✅ Date | ❌ | CLDR pattern with era marker |
| `May 5, 2026 – May 10, 2026` (en) | ✅ Date.Range | ❌ | CLDR interval pattern |
| `Sat, 23 May 2026 14:30:00 +1000` (RFC 2822) | ❌ | ❌ | Not in CLDR |
| `Sat, 23 May 2026 14:30:00 GMT` (HTTP date) | ❌ | ❌ | Not in CLDR |
| `Sat May 23 14:30:00 2026` (asctime) | ❌ | ❌ | Not in CLDR |
| `1748005800` (Unix timestamp) | ❌ | use `DateTime.from_unix/1` | |
| `/Date(1748005800000)/` (Microsoft) | ❌ | ❌ | |

## ISO 8601 coverage

Calendrical handles the ISO 8601 extended format end-to-end:

```elixir
iex> Calendrical.parse("2026-05-23")
{:ok, ~D[2026-05-23]}

iex> Calendrical.parse("2026-05-23T14:30:00")
{:ok, ~N[2026-05-23 14:30:00]}

iex> Calendrical.parse("2026-05-23T14:30:00Z")
{:ok, ~U[2026-05-23 14:30:00Z]}

iex> Calendrical.parse("2026-05-23T14:30:00+10:00")
{:ok, ~U[2026-05-23 04:30:00Z]}
```

For ISO 8601 forms the Elixir stdlib does not handle, Calendrical provides its own implementations:

```elixir
# Basic format (no separators)
iex> Calendrical.parse("20260523")
{:ok, ~D[2026-05-23]}

# Ordinal date (year + day-of-year, 1..366)
iex> Calendrical.parse("2026-143")
{:ok, ~D[2026-05-23]}

# Week date (ISO 8601 week-numbering year + week + day-of-week)
iex> Calendrical.parse("2026-W21-6")
{:ok, ~D[2026-05-23]}
```

The space-separated datetime form (`YYYY-MM-DD HH:MM:SS`) is accepted because the stdlib already accepts it and it's common in SQL output, log lines, and human-readable timestamps.

## Locale-aware parsing

Beyond ISO 8601, every parser tries the locale's CLDR patterns. The same input parses differently under different locales, by design:

```elixir
iex> Calendrical.parse("3/4/26", locale: :en)
{:ok, ~D[2026-03-04]}        # M/d/y

iex> Calendrical.parse("3/4/26", locale: :"en-GB")
{:ok, ~D[2026-04-03]}        # d/M/y

iex> Calendrical.parse("16.05.2026", locale: :de)
{:ok, ~D[2026-05-16]}        # dd.MM.y
```

The parser reads CLDR's full `availableFormats` skeleton set for each locale — so inputs that match any locale-published pattern parse, not just the four `dateStyle`/`timeStyle` references.

### Calendar option

Pass `:calendar` to interpret input in any of CLDR's calendars:

```elixir
iex> Calendrical.parse("2026-05-16", calendar: :hebrew)
{:ok, ~D[5786-09-29 Calendrical.Hebrew]}

iex> Calendrical.parse("民國115年5月16日", locale: :"zh-Hant-TW", calendar: :roc)
{:ok, ~D[0115-05-16 Calendrical.Roc]}

iex> Calendrical.parse("١٧ رمضان ١٤٣٥ هـ", locale: :"ar-SA", calendar: :islamic_civil)
{:ok, ~D[1435-09-17 Calendrical.Islamic.Civil]}
```

`:calendar` accepts either a CLDR calendar atom (`:gregorian`, `:hebrew`, …) or a calendar module (`Calendar.ISO`, `Calendrical.Hebrew`, …).

### Lenience (TR35 §6.5)

The parsers follow CLDR's lenient-parsing rules:

* **Case-insensitive name matching** — `"23 MAI"`, `"23 Mai"`, and `"23 mai"` all parse identically in French.
* **Equivalent separators** — `5/16/26`, `5-16-26`, and `5.16.26` all parse as `~D[2026-05-16]` in `:en` because CLDR's lenient-scope class treats `/`, `-`, and `.` interchangeably.
* **Non-Latin digits transliterated** — `٢٤` (Arabic-Indic 24) and `24` both parse identically.
* **Two-digit year pivoting** — `5/16/26` pivots into the 80-back/20-forward window relative to today (or `:reference_date` if you pass one). Era-aware calendars (Japanese, ROC) skip pivoting because the year is meant literally.
* **M↔d order swap for name months** — `"May 23"` parses in French (where CLDR's pattern is `d MMM`) and `"23 May"` parses in English (where it's `MMM d, y`). The swap applies only when the month is in name form (`MMM`/`MMMM`/`MMMMM`); numeric `M`/`MM` is excluded because the swap would be ambiguous with `d`.

## Variance from CLDR

Calendrical *deliberately* accepts inputs that CLDR doesn't strictly publish, where doing so is unambiguous and useful:

| Behaviour | CLDR baseline | Calendrical |
|---|---|---|
| ISO 8601 extended `YYYY-MM-DD` | Not a CLDR locale pattern | Accepted in every locale as an escape hatch |
| ISO 8601 basic `YYYYMMDD` | Not a CLDR pattern | Accepted via Calendrical's own parser |
| ISO 8601 ordinal `YYYY-DDD` | Not a CLDR pattern | Accepted via Calendrical's own parser |
| ISO 8601 week date `YYYY-Www-D` | Not a CLDR pattern | Accepted via Calendrical's own parser |
| Space separator in datetime | Stdlib accepts, CLDR doesn't define | Accepted |
| M↔d order swap | CLDR publishes one ordering per locale | Both orderings accepted when M is a name form |
| Case-insensitive name matching | TR35 §6.5 specifies it; CLDR data is one-case | Accepted any case |
| Lenient separator equivalence | TR35 §6.4 specifies it | Accepted per locale's lenient-scope class |

## Unified parser dispatch

`Calendrical.parse/2` tries the sub-parsers in this order:

1. **Interval** — only when an interval-shaped separator is present (the locale's `intervalFormatFallback`, or `–`, `—`, `−`, `〜`, `~`, ` to `, ` - `, ` / `). Cheap fail-fast.
2. **Date** — whole-string anchored; date-only input.
3. **Time** — whole-string anchored; time-only input.
4. **DateTime** — splits on every glue separator position; the most expensive parser, run last as a fallback for inputs with both date and time.

The returned struct discloses what was parsed:

```elixir
case Calendrical.parse(input, locale: :en) do
  {:ok, %Date.Range{} = r} -> handle_interval(r)
  {:ok, %Date{} = d}       -> handle_date(d)
  {:ok, %Time{} = t}       -> handle_time(t)
  {:ok, %NaiveDateTime{} = ndt} -> handle_naive_datetime(ndt)
  {:ok, %DateTime{} = dt}  -> handle_datetime(dt)
  {:error, %Calendrical.ParseError{attempts: attempts}} -> handle_failure(attempts)
end
```

## Error handling

All parsers return `{:ok, value} | {:error, exception}` and never raise on bad input. The exceptions are structured — pattern-match on the semantic fields rather than the rendered message:

| Exception | Fields |
|---|---|
| `Calendrical.DateParseError` | `:input`, `:locale`, `:calendar` |
| `Calendrical.TimeParseError` | `:input`, `:locale` |
| `Calendrical.DateTimeParseError` | `:input`, `:locale` |
| `Calendrical.DateRangeParseError` | `:input`, `:reason`, `:locale`, `:from`, `:to`, `:cause` |
| `Calendrical.ParseError` (unified) | `:input`, `:locale`, `:attempts` |

`DateRangeParseError`'s `:reason` is one of `:no_separator`, `:inverted`, `:from_parse_failed`, `:to_parse_failed` (declared via `reason_atoms/0`).

`ParseError`'s `:attempts` is a keyword list of `{kind, exception}` recording each sub-parser tried — useful for debugging "why didn't this parse?" without re-running.

## What to use for what

| Use case | Recommendation |
|---|---|
| Parsing a known-shape ISO string | `Calendrical.Date.parse/2` (or stdlib `Date.from_iso8601/1` for the extended subset) |
| Parsing a known-shape user input | The targeted parser (`Calendrical.Date.parse/2`, etc.) |
| Parsing input where the shape is unknown | `Calendrical.parse/2` |
| Date range from "May 5 – May 10, 2026" | `Calendrical.Date.parse_range/2` |
| Unix timestamp | Stdlib `DateTime.from_unix/1` |
| RFC 2822 / HTTP date | A dedicated library (Calendrical does not parse these) |
| `Date.toString()` / asctime | A dedicated library (Calendrical does not parse these) |
