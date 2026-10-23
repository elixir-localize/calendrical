defmodule Calendrical.DocCoverage.Test do
  use ExUnit.Case, async: true

  # Modules whose documented examples no other test runs.
  doctest Calendrical.Era
  doctest Calendrical.FiscalYear
  doctest Calendrical.Gregorian
  doctest Calendrical.ISO
  doctest Calendrical.ISOWeek
  doctest Calendrical.Islamic.UmmAlQura.Astronomical
  doctest Calendrical.Islamic.UmmAlQura.ReferenceData
  doctest Calendrical.Julian
  doctest Calendrical.Lunisolar
  doctest Calendrical.NRF
  doctest Calendrical.Period
  doctest Calendrical.Shift
end
