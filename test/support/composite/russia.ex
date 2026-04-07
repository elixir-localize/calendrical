defmodule Calendrical.Russia do
  @moduledoc """
  A composite calendar that tracks the historical calendar in use
  in Russia.

  ## Transitions

  * **(base)** — Julian calendar with the year starting on March 1
    (Byzantine *Annunciation Style*).
  * **1492-09-01** — switch to a Julian calendar with the year
    starting on September 1 (Byzantine *Anno Mundi*).
  * **1700-01-01** — switch to a Julian calendar with the year
    starting on January 1 (Peter the Great's reform).
  * **1918-02-14** — switch to the proleptic Gregorian calendar
    (the Soviet Decree on the introduction of the Western European
    calendar). The thirteen days 1 February 1918 through 13 February
    1918 are skipped.

  """
  use Calendrical.Composite,
    calendars: [
      ~D[1492-09-01 Calendrical.Julian.Sept1],
      ~D[1700-01-01 Calendrical.Julian.Jan1],
      ~D[1918-02-14 Calendrical.Gregorian]
    ],
    base_calendar: Calendrical.Julian.March1
end
