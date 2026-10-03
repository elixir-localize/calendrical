defmodule Calendrical.DayOfEraTest do
  @moduledoc """
  A month or week calendar's `day_of_era/3` gives a date the era of its
  calendar year, as `year_of_era/3` does: era 1 counts from the first day
  of calendar year 1, and era 0 back from the last day of calendar year 0,
  as `Calendar.ISO` counts its days. A fiscal year 0 that runs into AD 1
  keeps those days in era 0, where they took the Gregorian date's era.

  """

  use ExUnit.Case, async: true

  {:ok, fiscal_year_us} = Calendrical.FiscalYear.calendar_for(:US)
  {:ok, fiscal_year_au} = Calendrical.FiscalYear.calendar_for(:AU)

  @calendars [
    Calendrical.Gregorian,
    Calendrical.ISO,
    Calendrical.ISOWeek,
    Calendrical.NRF,
    Calendrical.IL,
    Calendrical.Fiscal.US,
    Calendrical.Fiscal.UK,
    Calendrical.Fiscal.AU,
    fiscal_year_us,
    fiscal_year_au
  ]

  @days Date.range(~D[-0002-01-01], ~D[0002-12-31])

  defp convert(gregorian, calendar) do
    {:ok, date} = Date.convert(gregorian, calendar)
    date
  end

  defp day_of_era(%{year: year, month: month, day: day, calendar: calendar}),
    do: calendar.day_of_era(year, month, day)

  for calendar <- @calendars do
    test "#{inspect(calendar)} counts each era's days in its calendar years" do
      calendar = unquote(calendar)
      dates = Enum.map(@days, &convert(&1, calendar))

      for date <- dates do
        {_year, era} = calendar.year_of_era(date.year, date.month, date.day)
        assert {_day, ^era} = day_of_era(date), inspect(date)
      end

      dates
      |> Enum.map(&day_of_era/1)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn
        [{day, 0}, {next, 0}] -> assert next == day - 1
        [{1, 0}, {next, 1}] -> assert next == 1
        [{day, 1}, {next, 1}] -> assert next == day + 1
      end)
    end
  end

  test "a year that begins on 1 January counts as Calendar.ISO does" do
    for calendar <- [Calendrical.Gregorian, Calendrical.ISO, Calendrical.IL],
        gregorian <- Enum.concat(@days, Date.range(~D[2018-12-25], ~D[2019-01-07])) do
      assert day_of_era(convert(gregorian, calendar)) ==
               Calendar.ISO.day_of_era(gregorian.year, gregorian.month, gregorian.day)
    end
  end

  test "a fiscal year 1 begins era 1" do
    # The US fiscal year 1 began on 1 October of the year 0, 1 BC.
    assert day_of_era(convert(~D[0000-10-01], Calendrical.Fiscal.US)) == {1, 1}
    assert day_of_era(convert(~D[0000-09-30], Calendrical.Fiscal.US)) == {1, 0}

    # NRF's year 0 runs into AD 1: its last day is the last of era 0.
    first = Calendrical.NRF.first_gregorian_day_of_year(1)
    assert day_of_era(convert(Date.from_gregorian_days(first), Calendrical.NRF)) == {1, 1}
    assert day_of_era(convert(Date.from_gregorian_days(first - 1), Calendrical.NRF)) == {1, 0}
    assert Date.from_gregorian_days(first - 1).year == 1
  end
end
