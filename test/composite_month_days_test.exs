defmodule Calendrical.CompositeMonthDaysTest do
  @moduledoc """
  A composite's `days_in_month/2` counts the days that carry the month's
  label, so a month no day carries has none, and `months_in_year/1` is the
  number of the year's last month that has days, `0` for a year no day
  carries. The hand-derived years are England's 1751, which began on Lady
  Day, Russia's 1492, which ended on 31 August, and the years between
  Japan's last lunisolar year and 1873, which no day carries. Every year
  around every change of each composite is then checked against the days
  `valid_date?/3` accepts.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Japan, Sweden}

  defp days_in_months(calendar, year) do
    for month <- 1..12, do: calendar.days_in_month(year, month)
  end

  test "England's 1751 began on 25 March" do
    assert days_in_months(England, 1751) == [0, 0, 7, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    assert England.months_in_year(1751) == 12
    assert England.days_in_year(1751) == 282
  end

  test "Russia's 1492 ended on 31 August" do
    assert days_in_months(Calendrical.Russia, 1492) == [0, 0, 31, 30, 31, 30, 31, 31, 0, 0, 0, 0]
    assert Calendrical.Russia.months_in_year(1492) == 8
    assert Calendrical.Russia.days_in_year(1492) == 184
  end

  test "Japan's years between its lunisolar calendar and 1873 have no months" do
    for year <- [1229, 1500, 1872] do
      assert Japan.months_in_year(year) == 0
      assert Japan.days_in_year(year) == 0
      assert Enum.all?(1..13, &(Japan.days_in_month(year, &1) == 0))
    end

    assert Japan.months_in_year(1873) == 12
  end

  for calendar <- [England, Sweden, Japan, Calendrical.Russia] do
    test "#{inspect(calendar)}'s months have the days valid_date?/3 accepts" do
      calendar = unquote(calendar)

      for year <- years_around_changes(calendar), month <- 1..13 do
        days = Enum.count(1..31, &calendar.valid_date?(year, month, &1))
        months_in_year = calendar.months_in_year(year)

        if month <= months_in_year do
          assert calendar.days_in_month(year, month) == days, "#{year}-#{month}"
        else
          assert days == 0, "#{year}-#{month} has days after month #{months_in_year}"
        end

        if month == months_in_year, do: assert(days > 0, "#{year} ends in month #{month}")
      end
    end
  end

  defp years_around_changes(calendar) do
    calendar.__config__()
    |> Enum.flat_map(fn {iso_days, _year, _month, _day, _calendar} ->
      [iso_days - 400, iso_days - 1, iso_days, iso_days + 400]
    end)
    |> Enum.map(&elem(calendar.date_from_iso_days(&1), 0))
    |> Enum.flat_map(&[&1 - 1, &1, &1 + 1])
    |> Enum.uniq()
  end
end
