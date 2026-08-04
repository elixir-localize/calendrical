defmodule Calendrical.Reform.Sweden do
  @moduledoc """
  A composite calendar that tracks the historical calendar in use in Sweden.

  Sweden's path from the Julian to the Gregorian calendar is the most unusual in
  Europe, and makes a good demonstration of `Calendrical.Composite`: it splices
  four calendars, drops a leap day, and includes the only known **30 February**.

  ## Transitions

  * **(base)** — the Julian calendar.

  * **1700-03-01** — Sweden begins a gradual transition by omitting the leap day
    of 1700 (there is no 29 February 1700) and switches to the transitional
    `Calendrical.Reform.Sweden.Transitional` calendar, which runs one day ahead of the
    Julian calendar.

  * **1712-03-01** — Sweden abandons the transition and reverts to the Julian
    calendar. To realign, an extra day — **30 February 1712** — is inserted at
    the end of the transitional period.

  * **1753-03-01** — Sweden adopts the proleptic Gregorian calendar. The eleven
    days 18 February 1753 through 28 February 1753 are skipped.

  ## Examples

      # 30 February 1712 is a valid date in Sweden
      iex> Calendrical.Reform.Sweden.valid_date?(1712, 2, 30)
      true

      # There is no 29 February 1700
      iex> Calendrical.Reform.Sweden.valid_date?(1700, 2, 29)
      false

      # The eleven days lost to the 1753 Gregorian adoption
      iex> Calendrical.Reform.Sweden.valid_date?(1753, 2, 20)
      false

  ## Reference

  For a source-referenced survey of how other territories moved to the
  Gregorian calendar, see `Calendrical.Reform` and Giuseppe Giudice's
  [The adoption of the Gregorian calendar](https://web.archive.org/web/20130315080715/http://dpgi.unina.it/giudice/calendar/Adoption.html).

  """
  use Calendrical.Composite,
    calendars: [
      ~D[1700-03-01 Calendrical.Reform.Sweden.Transitional],
      ~D[1712-03-01 Calendrical.Julian],
      ~D[1753-03-01 Calendrical.Gregorian]
    ],
    base_calendar: Calendrical.Julian
end
