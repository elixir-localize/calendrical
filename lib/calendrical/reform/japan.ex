defmodule Calendrical.Reform.Japan do
  @moduledoc """
  A composite calendar that tracks the historical calendar in use in Japan.

  Unlike the European reforms, Japan did not move from the Julian calendar to
  the Gregorian calendar. Before 1873 Japan used the Tenpō *lunisolar* calendar
  (`Calendrical.LunarJapanese`); it adopted the Gregorian calendar as part of the
  Meiji reforms. This makes `Calendrical.Reform.Japan` a good example of a
  composite that splices a lunisolar calendar with a solar one.

  The Gregorian side uses `Calendrical.Japanese` rather than
  `Calendrical.Gregorian`, so post-reform dates carry Japanese era years
  (Meiji, Taishō, Shōwa, Heisei, Reiwa) when localized — 1 January 1873 is
  Meiji 6.

  ## Transitions

  * **(base)** — the Japanese lunisolar calendar (`Calendrical.LunarJapanese`).

  * **1873-01-01** — Japan adopts the Gregorian calendar (as
    `Calendrical.Japanese`). The last lunisolar day, Meiji 5, month 12, day 2
    (31 December 1872 in the Gregorian calendar), is followed directly by
    1 January 1873. No physical days are skipped — only the remainder of the
    lunisolar month is dropped.

  Because `Calendrical.LunarJapanese` numbers years continuously from the Taika
  era (645 CE), pre-reform dates carry that year number rather than an era-based
  year such as "Meiji 5".

  ## Examples

      # The physical day before the reform, in the lunisolar calendar
      iex> Date.convert!(~D[1873-01-01 Calendrical.Reform.Japan], Calendrical.Gregorian)
      ~D[1873-01-01 Calendrical.Gregorian]

      iex> Date.convert!(~D[1873-01-01 Calendrical.Gregorian], Calendrical.Reform.Japan)
      ~D[1873-01-01 Calendrical.Reform.Japan]

  ## Reference

  See `Calendrical.Reform` for the reform dates of other territories and the
  sources they are drawn from.

  """
  use Calendrical.Composite,
    calendars: [
      ~D[1873-01-01 Calendrical.Japanese]
    ],
    base_calendar: Calendrical.LunarJapanese
end
