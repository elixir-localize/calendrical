defmodule Calendrical.LunisolarYearRoundTripTest do
  @moduledoc """
  A lunisolar date read back from its day is the date: the year a day
  falls in is the one whose first day `date_to_iso_days/3` places, through
  every year the calendars number. The lunisolar Japanese calendar's epoch,
  20 July 645, is 165 days after its year 1 began, and counting mean years
  from it read the first day of year -10001 as year -10002.

  """

  use ExUnit.Case, async: true

  @calendars [
    Calendrical.Chinese,
    Calendrical.Korean,
    Calendrical.Vietnamese,
    Calendrical.LunarJapanese
  ]

  defp round_trips(calendar, year) do
    last_month = calendar.months_in_year(year)
    last_day = calendar.days_in_month(year, last_month)

    for date <- [{year, 1, 1}, {year, last_month, last_day}] do
      {year, month, day} = date
      {date, calendar.date_from_iso_days(calendar.date_to_iso_days(year, month, day))}
    end
    |> Enum.reject(fn {date, read_back} -> date == read_back end)
  end

  test "the lunisolar Japanese calendar's year -10001 and its neighbours" do
    for year <- -10_003..-9_990 do
      assert round_trips(Calendrical.LunarJapanese, year) == [], "year #{year}"
    end

    assert Calendrical.LunarJapanese.date_from_iso_days(
             Calendrical.LunarJapanese.date_to_iso_days(-10_001, 1, 1)
           ) == {-10_001, 1, 1}
  end

  test "year 1 begins where it did" do
    assert Date.from_gregorian_days(Calendrical.Chinese.date_to_iso_days(1, 1, 1)) ==
             ~D[-2636-02-15]

    assert Date.from_gregorian_days(Calendrical.LunarJapanese.date_to_iso_days(1, 1, 1)) ==
             ~D[0645-02-05]
  end

  @tag :full
  @tag timeout: :infinity
  test "every calendar's years read back from -10001 to 9999" do
    years = Enum.concat([-10_001..-9_995, -9_990..9_990//389, 9_995..9_999])

    for calendar <- @calendars, year <- years do
      assert round_trips(calendar, year) == [], "#{inspect(calendar)} year #{year}"
    end
  end
end
