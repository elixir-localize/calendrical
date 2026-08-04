# Composite calendars

A **composite calendar** stitches two or more calendars together at historical
cut‑over dates, so a single calendar module can represent a place whose calendar
system changed over time. This is exactly what happened across the world as
territories moved from the Julian to the Gregorian calendar — and, in Japan's
case, from a lunisolar calendar to the Gregorian one.

`Calendrical.Composite` builds these calendars. The resulting module is an
ordinary `Calendar` implementation: it works with `Date.new/4`, `Date.shift/2`,
`Date.convert/2`, `Calendrical.Interval`, the `~D` sigil, and every other
Calendrical function.

## Defining a composite

A composite is declared with `use Calendrical.Composite`, a `:base_calendar`
(the calendar in effect before the first transition) and a `:calendars` list of
transition markers. **Each marker is a date written in the calendar that takes
effect on that day.**

England is the classic example. It changed the civil New Year from 25 March to
1 January, and then dropped eleven days when it adopted the Gregorian calendar in
1752:

```elixir
defmodule CompositeCalendar.England do
  use Calendrical.Composite,
    calendars: [
      ~D[1155-03-25 Calendrical.Julian.March25],
      ~D[1751-03-25 Calendrical.Julian.Jan1],
      ~D[1752-09-14 Calendrical.Gregorian]
    ],
    base_calendar: Calendrical.Julian
end
```

Read the `:calendars` list as "on this day, switch to this calendar":

* before 1155‑03‑25 — the base `Calendrical.Julian` calendar;
* from 1155‑03‑25 — Julian with the year starting on 25 March (Lady Day);
* from 1751‑03‑25 — Julian with the year starting on 1 January;
* from 1752‑09‑14 — the proleptic Gregorian calendar.

## "Missing" days

When a territory adopts the Gregorian calendar it skips the days by which the
Julian calendar had drifted. In September 1752 England went straight from the
2nd to the 14th, so that month has only 19 days and the days in between are not
valid dates:

```elixir
iex> CompositeCalendar.England.days_in_month(1752, 9)
19

iex> CompositeCalendar.England.valid_date?(1752, 9, 3)
false

iex> Date.shift(~D[1752-09-02 CompositeCalendar.England], day: 1)
~D[1752-09-14 CompositeCalendar.England]
```

The composite rejects the skipped days because their ISO day number belongs to
the calendar on the *other* side of the transition — a date is valid only if it
round‑trips to the same member calendar.

## Changing when the year starts

Transitions can also change *year numbering* rather than skip days. Under the
March‑25 (Lady Day) style, the day after 24 March 1750 is 25 March **1751**;
after the switch to a January start, 1751 becomes the first year to run all the
way to 31 December, followed directly by 1 January 1752:

```elixir
iex> Date.shift(~D[1750-03-24 CompositeCalendar.England], day: 1)
~D[1751-03-25 CompositeCalendar.England]

iex> Date.shift(~D[1751-12-31 CompositeCalendar.England], day: 1)
~D[1752-01-01 CompositeCalendar.England]
```

## Multiple transitions — and a 30 February

Sweden has the most unusual history in Europe, and `Calendrical.Reform.Sweden`
(shipped with Calendrical) models it faithfully with four segments. Sweden
dropped the leap day in 1700 to begin a gradual transition, ran one day ahead of
the Julian calendar until 1712, then reverted to Julian by inserting the only
known **30 February**, before finally adopting the Gregorian calendar in 1753:

```elixir
# There was no 29 February 1700
iex> Calendrical.Reform.Sweden.valid_date?(1700, 2, 29)
false

# 30 February 1712 really existed in Sweden
iex> Calendrical.Reform.Sweden.valid_date?(1712, 2, 30)
true

iex> Calendrical.Reform.Sweden.days_in_month(1712, 2)
30

# The final Gregorian adoption skips eleven days in 1753
iex> Date.shift(~D[1753-02-17 Calendrical.Reform.Sweden], day: 1)
~D[1753-03-01 Calendrical.Reform.Sweden]
```

Russia is a simpler multi‑transition example — Byzantine year‑start styles
followed by the Soviet 1918 Gregorian decree, which skipped thirteen days
(1–13 February 1918).

## Splicing a lunisolar calendar

Composites are not limited to Julian and Gregorian segments. Japan moved from a
*lunisolar* calendar to the Gregorian one in 1873, and `Calendrical.Reform.Japan`
splices `Calendrical.LunarJapanese` with `Calendrical.Japanese`:

```elixir
# The last lunisolar day is followed directly by 1 January 1873 —
# no physical days are skipped, only the rest of the lunisolar month.
iex> Date.shift(~D[1228-12-02 Calendrical.Reform.Japan], day: 1)
~D[1873-01-01 Calendrical.Reform.Japan]

# Because the Gregorian side is Calendrical.Japanese, dates carry era years:
# 1873 is Meiji 6.
iex> Calendrical.Reform.Japan.year_of_era(1873, 1, 1)
{6, 232}
```

## Runtime and territory‑driven composites

Composites can be built at runtime with `Calendrical.Composite.new/2`:

```elixir
iex> Calendrical.Composite.new(CompositeCalendar.Denmark,
...>   calendars: [~D[1700-03-01 Calendrical.Gregorian]],
...>   base_calendar: Calendrical.Julian)
{:ok, CompositeCalendar.Denmark}
```

For the common Julian‑to‑Gregorian case, `Calendrical.Reform` already knows the
reform date of every territory in the `ncal(1)` table and builds the calendar
for you — accepting a territory code or a `Localize.LanguageTag`:

```elixir
iex> Calendrical.Reform.calendar_for(:GB)
{:ok, Calendrical.Reform.GB}

iex> Calendrical.Reform.reforms()[:RU]
%{
  country: "Russia",
  last_julian: ~D[1918-01-31 Calendrical.Julian],
  first_gregorian: ~D[1918-02-14 Calendrical.Gregorian]
}
```

`Calendrical.Reform.calendar_for/1` returns the curated `Calendrical.Reform.Sweden`
and `Calendrical.Reform.Japan` for those two territories, and an `ncal`‑derived
composite for the rest. See `Calendrical.Reform` for the reform dates, their
sources, and the territories where a single national date is only an
approximation.
