defmodule Calendrical.NumericMonthTest do
  @moduledoc """
  The day and the month a date is written with in figures, which every
  calendar answers (`cardinal_day/3`, `numeric_month/3`) and
  `Calendrical.strftime/3` writes `%d` and `%m` from.

  `cardinal_day/3` was a callback only a calendar that renumbers its days
  had, and `strftime/3` asked whether a calendar exported it to know whether
  to write the named day and month. Every calendar answers both now: its
  fields, unless it counts its months from a new-year day and writes its
  dates by the months that name them. A fiscal calendar's months are named
  as the Gregorian months they are, so its dates are written as the
  Gregorian dates they are (user, 2026-10-16): the fiscal year from July
  whose year 2026 begins in July 2025 writes its month 1 day 15 as
  15/07/2025, while its `year_of_era/1` and its ranges stay the fiscal
  year's.

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
      {:ok, _fiscal} =
        Calendrical.new(Calendrical.NumericMonthTest.FiscalFromJuly, :month, year_begins: {7, 1})

      assert written(~D[2025-06-16 Calendrical.Gregorian]) == {16, 6}
      assert written(~D[1750-06-05 Calendrical.Julian]) == {5, 6}
      assert written(~D[5785-09-20 Calendrical.Hebrew]) == {20, 9}
      assert written(~D[1404-03-26 Calendrical.Persian]) == {26, 3}
    end

    # The fiscal year 2026 from July begins on 1 July 2025: its month 1 is
    # July, written with the Gregorian year it falls in.
    test "are the Gregorian day and month in a fiscal calendar, with the Gregorian year" do
      {:ok, fiscal} =
        Calendrical.new(Calendrical.NumericMonthTest.FiscalFromJuly, :month, year_begins: {7, 1})

      assert written(Date.new!(2026, 1, 15, fiscal)) == {15, 7}
      assert fiscal.cardinal_year(2026, 1, 15) == 2025

      assert written(Date.new!(2026, 7, 15, fiscal)) == {15, 1}
      assert fiscal.cardinal_year(2026, 7, 15) == 2026

      assert fiscal.date_from_cardinal_date(2025, 7, 15) == {2026, 1, 15}
      assert fiscal.date_from_cardinal_date(2026, 1, 15) == {2026, 7, 15}

      assert {:error, %Calendrical.InvalidDateError{}} =
               fiscal.date_from_cardinal_date(2025, 2, 30)
    end

    # Week 25's first day is the fifteenth of the sixth month of the pattern.
    test "are its month and its day in a calendar of weeks, as in any calendar" do
      assert written(Date.new!(2025, 6, 15, Calendrical.ISOWeek)) == {15, 6}
      assert Calendrical.ISOWeek.week_date_from_date(2025, 6, 15) == {2025, 25, 1}
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

    test "writes a fiscal date as the Gregorian date it is" do
      {:ok, fiscal} =
        Calendrical.new(Calendrical.NumericMonthTest.FiscalFromJuly, :month, year_begins: {7, 1})

      assert Calendrical.strftime(Date.new!(2026, 1, 15, fiscal), "%d/%m/%Y, %-d %B", locale: :en) ==
               {:ok, "15/07/2025, 15 July"}

      assert Calendrical.strftime(Date.new!(2026, 1, 15, fiscal), "%y|%_6Y|%-Y") ==
               {:ok, "25|  2025|2025"}
    end

    test "writes %d and %m from the fields of a calendar that numbers its months as it writes them" do
      assert Calendrical.strftime(~D[5785-09-20 Calendrical.Hebrew], "%d/%m/%Y, %-d %B",
               locale: :en
             ) == {:ok, "20/09/5785, 20 Sivan"}

      assert Calendrical.strftime(Date.new!(2025, 6, 15, Calendrical.ISOWeek), "%d/%m/%Y") ==
               {:ok, "15/06/2025"}
    end

    test "keeps the padding of a field it writes" do
      assert Calendrical.strftime(~D[1750-01-01 Calendrical.Julian.March25], "%_m|%05d|%-m") ==
               {:ok, " 3|00025|3"}
    end
  end
end
