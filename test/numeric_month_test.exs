defmodule Calendrical.NumericMonthTest do
  @moduledoc """
  The day and the month a date is written with in figures, which every
  calendar answers (`cardinal_day/3`, `numeric_month/3`) and
  `Calendrical.strftime/3` writes `%d` and `%m` from.

  `cardinal_day/3` was a callback only a calendar that renumbers its days
  had, and `strftime/3` asked whether a calendar exported it to know whether
  to write the named day and month. Every calendar answers both now: its
  fields, unless it counts its months from a new-year day and writes its
  dates by the months that name them.

  The dates are worked out by hand. The Lady Day year 1750 begins on 25
  March, so its month 1 day 1 is 25 March, its month 2 is April, and its
  month 13 the days of March before the 25th. A year beginning on 1 March
  or 1 September has those months for its first, and one beginning on 25
  December has that day for its first.

  """

  use ExUnit.Case, async: true

  defp written(%Date{year: year, month: month, day: day, calendar: calendar}),
    do: {calendar.cardinal_day(year, month, day), calendar.numeric_month(year, month, day)}

  describe "the day and the month a date is written with in figures" do
    test "are its fields in a calendar that numbers its months as it writes them" do
      {:ok, fiscal} =
        Calendrical.new(Calendrical.NumericMonthTest.FiscalFromJuly, :month, month_of_year: 7)

      assert written(~D[2025-06-16 Calendrical.Gregorian]) == {16, 6}
      assert written(~D[1750-06-05 Calendrical.Julian]) == {5, 6}
      assert written(~D[5785-09-20 Calendrical.Hebrew]) == {20, 9}
      assert written(~D[1404-03-26 Calendrical.Persian]) == {26, 3}

      # The first month of a fiscal year from July is its period 1.
      assert written(Date.new!(2026, 1, 15, fiscal)) == {15, 1}
    end

    test "are its week and its day of the week in a calendar of weeks" do
      assert written(Date.new!(2025, 25, 1, Calendrical.ISOWeek)) == {1, 25}
    end

    test "are the Julian day and month in a calendar that counts its months from a new-year day" do
      assert written(~D[1750-01-01 Calendrical.Julian.March25]) == {25, 3}
      assert written(~D[1750-02-05 Calendrical.Julian.March25]) == {5, 4}
      assert written(~D[1750-13-24 Calendrical.Julian.March25]) == {24, 3}
      assert written(~D[1750-01-05 Calendrical.Julian.March1]) == {5, 3}
      assert written(~D[1750-01-05 Calendrical.Julian.Sept1]) == {5, 9}
      assert written(~D[1750-01-01 Calendrical.Julian.Dec25]) == {25, 12}
      assert written(~D[1750-06-05 Calendrical.Julian.Jan1]) == {5, 6}
    end

    test "are those of the calendar in effect on the date in a composite calendar" do
      # England's year began on 25 March until 1751, and on 1 January after.
      assert written(~D[1750-01-01 Calendrical.Reform.England]) == {25, 3}
      assert written(~D[1750-02-05 Calendrical.Reform.England]) == {5, 4}
      assert written(~D[1760-06-05 Calendrical.Reform.England]) == {5, 6}
    end
  end

  describe "Calendrical.strftime/3" do
    test "writes %d and %m as the named day and month, so the date in figures is the date in words" do
      assert Calendrical.strftime(~D[1750-01-01 Calendrical.Julian.March25], "%d/%m/%Y, %-d %B",
               locale: :en
             ) == {:ok, "25/03/1750, 25 March"}

      assert Calendrical.strftime(~D[1750-13-24 Calendrical.Julian.March25], "%d/%m/%Y, %-d %B",
               locale: :en
             ) == {:ok, "24/03/1750, 24 March"}

      assert Calendrical.strftime(~D[1750-01-05 Calendrical.Julian.Sept1], "%d/%m/%Y, %-d %B",
               locale: :en
             ) == {:ok, "05/09/1750, 5 September"}

      assert Calendrical.strftime(~D[1750-01-01 Calendrical.Reform.England], "%d/%m/%Y, %-d %B",
               locale: :en
             ) == {:ok, "25/03/1750, 25 March"}
    end

    test "writes %d and %m from the fields of a calendar that numbers its months as it writes them" do
      {:ok, fiscal} =
        Calendrical.new(Calendrical.NumericMonthTest.FiscalFromJuly, :month, month_of_year: 7)

      assert Calendrical.strftime(Date.new!(2026, 1, 15, fiscal), "%d/%m/%Y, %-d %B", locale: :en) ==
               {:ok, "15/01/2026, 15 July"}

      assert Calendrical.strftime(~D[5785-09-20 Calendrical.Hebrew], "%d/%m/%Y, %-d %B",
               locale: :en
             ) == {:ok, "20/09/5785, 20 Sivan"}

      assert Calendrical.strftime(Date.new!(2025, 25, 1, Calendrical.ISOWeek), "%d/%m/%Y") ==
               {:ok, "01/25/2025"}
    end

    test "keeps the padding of a field it writes" do
      assert Calendrical.strftime(~D[1750-01-01 Calendrical.Julian.March25], "%_m|%05d|%-m") ==
               {:ok, " 3|00025|3"}
    end
  end
end
