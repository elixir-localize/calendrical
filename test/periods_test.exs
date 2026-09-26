defmodule Calendrical.PeriodsTest do
  @moduledoc """
  Quarters, quadrimesters and semesters: runs of 3, 4 or 6 traditional
  months in every calendar, a leap month with the month it repeats and
  a thirteenth month in the last period, and `quarter_of_year/3` in
  agreement with `quarter/2`.

  """

  use ExUnit.Case, async: true

  @calendars (fn ->
                {:ok, modules} = :application.get_key(:calendrical, :modules)

                Enum.filter(modules, fn module ->
                  Code.ensure_loaded?(module) and function_exported?(module, :semester, 2) and
                    function_exported?(module, :calendar_base, 0)
                end)
              end).()

  defp months(%Date.Range{first: first, last: last}), do: {first.month, last.month}

  describe "leap months" do
    test "a Hebrew leap year's Adar I and Adar II are in the second quarter" do
      # 5786 is an ordinary year, 5787 a leap year.
      assert Enum.map(1..4, &months(Calendrical.Hebrew.quarter(5786, &1))) ==
               [{1, 3}, {4, 6}, {7, 9}, {10, 12}]

      assert Enum.map(1..4, &months(Calendrical.Hebrew.quarter(5787, &1))) ==
               [{1, 3}, {4, 7}, {8, 10}, {11, 13}]

      assert Enum.map(1..2, &months(Calendrical.Hebrew.semester(5787, &1))) == [{1, 7}, {8, 13}]
    end

    test "a lunisolar leap month is in the period of the month it repeats" do
      # Chinese 4662 has a leap sixth month at position 7.
      assert months(Calendrical.Chinese.quarter(4662, 2)) == {4, 7}
      assert months(Calendrical.Chinese.quadrimester(4662, 2)) == {5, 9}
    end
  end

  describe "a thirteenth month" do
    test "falls in the last period" do
      assert months(Calendrical.Coptic.quarter(1742, 4)) == {10, 13}
      assert months(Calendrical.Ethiopic.semester(2018, 2)) == {7, 13}
      assert Calendrical.Coptic.quarter_of_year(1742, 13, 1) == 4
    end
  end

  describe "the periods of every calendar" do
    test "tile the year, in order and without gaps" do
      for calendar <- @calendars,
          {:ok, today} <- [Date.convert(~D[2026-06-15], calendar)],
          {period, count} <- [quarter: 4, quadrimester: 3, semester: 2] do
        ranges = Enum.map(1..count, &apply(calendar, period, [today.year, &1]))
        year = calendar.year(today.year)

        assert hd(ranges).first == year.first, "#{inspect(calendar)} #{period}"
        assert List.last(ranges).last == year.last, "#{inspect(calendar)} #{period}"

        for {earlier, later} <- Enum.zip(ranges, tl(ranges)) do
          assert Date.diff(later.first, earlier.last) == 1, "#{inspect(calendar)} #{period}"
        end
      end
    end

    test "agree with quarter_of_year/3" do
      for calendar <- @calendars,
          {:ok, today} <- [Date.convert(~D[2026-06-15], calendar)],
          month <- 1..calendar.months_in_year(today.year),
          {:ok, date} <- [Date.new(today.year, month, 1, calendar)] do
        quarter = calendar.quarter_of_year(today.year, month, 1)
        assert date in calendar.quarter(today.year, quarter), "#{inspect(calendar)} #{month}"
      end
    end

    test "outside the year is an error" do
      assert Calendrical.Hebrew.quarter(5787, 5) == {:error, :invalid_date}
      assert Calendrical.Gregorian.quadrimester(2026, 4) == {:error, :invalid_date}
      assert Calendrical.Islamic.Civil.semester(1447, 0) == {:error, :invalid_date}
    end
  end

  describe "Calendrical.Interval" do
    test "quadrimester/3 and semester/3 take the calendar's periods" do
      assert months(Calendrical.Interval.quadrimester(2026, 3)) == {9, 12}
      assert months(Calendrical.Interval.semester(2026, 2, Calendrical.ISOWeek)) == {27, 53}
    end
  end
end
