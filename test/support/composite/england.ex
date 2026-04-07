defmodule Calendrical.England do
  @moduledoc """
  A composite calendar that tracks the historical calendar in use
  in England.

  ## Transitions

  * **1155-03-25** — switch to a Julian calendar with the year
    starting on March 25 (Lady Day / Annunciation Style).
  * **1751-03-25** — switch to a Julian calendar with the year
    starting on January 1.
  * **1752-09-14** — switch to the proleptic Gregorian calendar.
    The eleven days 3 September 1752 through 13 September 1752 are
    skipped (i.e. not valid dates in this calendar).

  ## References

  * <https://www.legislation.gov.uk/apgb/Geo2/24/23#commentary-c918471>
  * <https://libguides.ctstatelibrary.org/hg/colonialresearch/calendar>
  * <https://en.wikipedia.org/wiki/Julian_calendar>
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
