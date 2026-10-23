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
    # The March year's counted months 1 (March) to 6 (August) have days.
    assert days_in_months(Calendrical.Russia, 1492) == [31, 30, 31, 30, 31, 31, 0, 0, 0, 0, 0, 0]
    assert Calendrical.Russia.months_in_year(1492) == 6
    assert Calendrical.Russia.days_in_year(1492) == 184
  end

  test "Japan's years between its lunisolar calendar and 1873 have no months" do
    for year <- [1229, 1500, 1872] do
      assert Japan.months_in_year(year) == 0
      assert Japan.days_in_year(year) == {:error, :invalid_date}
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

  # The base calendar has no first day, so the years around a change are
  # those around each calendar that takes effect after it.
  defp years_around_changes(calendar) do
    calendar.__config__()
    |> Enum.drop(1)
    |> Enum.flat_map(fn {iso_days, _year, _month, _day, _calendar} ->
      [iso_days - 400, iso_days - 1, iso_days, iso_days + 400]
    end)
    |> Enum.map(&elem(calendar.date_from_iso_days(&1), 0))
    |> Enum.flat_map(&[&1 - 1, &1, &1 + 1])
    |> Enum.uniq()
  end

  # A question that needs no day takes the 1st of a month the year holds as
  # the month's first day, as a date without a day is asked about, where a
  # change of calendar began the month after its 1st: England's 1751 began
  # on 25 March, and Russia's February 1918 on the 14th. A year and a month
  # are written from the month's 1st, so Localize writes these months.
  describe "a month that begins after its 1st" do
    test "answers the questions that need no day through its 1st" do
      {:ok, russia} = Calendrical.Reform.calendar_for(:RU)

      refute England.valid_date?(1751, 3, 1)
      assert England.month_of_year(1751, 3, 1) == 3
      assert England.quarter_of_year(1751, 3, 1) == 1

      refute russia.valid_date?(1918, 2, 1)
      assert russia.month_of_year(1918, 2, 1) == 2
    end

    test "is still no date for a question about a day" do
      assert England.day_of_week(1751, 3, 1, :default) == {:error, :invalid_date}
      assert England.day_of_year(1751, 3, 1) == {:error, :invalid_date}
      assert England.month_of_year(1751, 3, 5) == {:error, :invalid_date}
    end

    # England's February 1751 holds no day: the year ran from 25 March.
    test "is no month where the month holds no day" do
      assert England.month_of_year(1751, 2, 1) == {:error, :invalid_date}
    end

    test "is written from its year and month" do
      {:ok, russia} = Calendrical.Reform.calendar_for(:RU)

      assert Localize.Date.to_string(%{year: 1751, month: 3, calendar: England},
               format: :yMMM,
               locale: :en
             ) == {:ok, "Mar 1751"}

      assert Localize.Date.to_string(%{year: 1918, month: 2, calendar: russia},
               format: :yMMM,
               locale: :en
             ) == {:ok, "Feb 1918"}
    end
  end
end
