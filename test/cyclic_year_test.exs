defmodule Calendrical.CyclicYearTest do
  @moduledoc """
  A lunisolar year's place in the sexagenary cycle, checked against
  ICU4C 78.3's Chinese and Dangi calendars.

  The cycle runs with the lunar year whatever year a calendar counts
  from, so the Korean and Lunar Japanese calendars, whose years are not
  numbered from the Chinese epoch, place a year as the Chinese one does.

  """

  use ExUnit.Case, async: true

  @calendars [
    Calendrical.Chinese,
    Calendrical.Korean,
    Calendrical.Vietnamese,
    Calendrical.LunarJapanese
  ]

  # ICU4C 78.3's `UCAL_YEAR` in the `chinese` and `dangi` calendars,
  # which agree on every one: 1700-02-10 is in the lunar year that
  # began in 1699.
  @icu_cyclic_years [
    {~D[1983-03-15], 60},
    {~D[1984-03-15], 1},
    {~D[2025-03-15], 42},
    {~D[2099-07-01], 56},
    {~D[1700-02-10], 16},
    {~D[-6000-07-01], 57}
  ]

  test "every lunisolar calendar places a year in the cycle as ICU does" do
    for calendar <- @calendars, {iso, expected} <- @icu_cyclic_years do
      date = Date.convert!(iso, calendar)

      assert calendar.cyclic_year(date.year, date.month, date.day) == expected,
             "#{inspect(calendar)} #{iso}"

      assert calendar.cyclic_year(date) == expected
      assert Calendrical.cyclic_year(date) == expected
    end
  end
end
