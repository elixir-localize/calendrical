defmodule Calendrical.Reform.England do
  @moduledoc """
  A composite calendar that tracks the historical calendar in use in England.

  England's road to the Gregorian calendar spans three transitions rather than a
  single cutover, which makes it a good demonstration of a composite that
  splices calendars differing in both their year-start and their leap rule. Two
  of the transitions only move where the year number changes; the third drops
  eleven days.

  ## Transitions

  * **(base)** — the Julian calendar.

  * **1155-03-25** — the year-start moves to March 25 (*Lady Day* /
    Annunciation Style), modelled by `Calendrical.Julian.March25`.

  * **1751-03-25** — the year-start moves to January 1, modelled by
    `Calendrical.Julian.Jan1`. As a result the calendar year 1751 is a short
    year: it runs from 25 March to 31 December.

  * **1752-09-14** — England adopts the proleptic Gregorian calendar. The eleven
    days 3 September 1752 through 13 September 1752 are skipped, so 2 September
    1752 is followed directly by 14 September 1752.

  ## Examples

      # The eleven days lost to the 1752 Gregorian adoption
      iex> Calendrical.Reform.England.valid_date?(1752, 9, 5)
      false

      iex> Date.shift(~D[1752-09-02 Calendrical.Reform.England], day: 1)
      ~D[1752-09-14 Calendrical.Reform.England]

      # 1751 is a short year, ending on 31 December
      iex> Date.shift(~D[1750-03-24 Calendrical.Reform.England], day: 1)
      ~D[1751-03-25 Calendrical.Reform.England]

  ## Reference

  See `Calendrical.Reform` for the reform dates of other territories and the
  sources they are drawn from.

  * <https://www.legislation.gov.uk/apgb/Geo2/24/23#commentary-c918471>
  * *Handbook of Dates for Students of British History* (Cheney & Jones).

  """
  use Calendrical.Composite,
    calendars: [
      ~D[1155-03-25 Calendrical.Julian.March25],
      ~D[1751-03-25 Calendrical.Julian.Jan1],
      ~D[1752-09-14 Calendrical.Gregorian]
    ],
    base_calendar: Calendrical.Julian
end
