defmodule Calendrical.MonthAndDayNumbersTest do
  @moduledoc """
  The months a year has and the days a month has, as the numbers themselves
  (`month_numbers/1`, `day_numbers/2`), which every calendar answers.

  `months_in_year/1` and `days_in_month/2` are counts, and say which values
  a year or a month has only where they run from 1 with none missing. A
  caller that wanted the values had to know which calendars are composites
  and work the values out for them.

  The values are known apart from the library. England began its year on
  25 March until 1751, which ran from 25 March to 31 December, and left
  out 3 to 13 September 1752. A Lady Day year counts thirteen months, the
  first its seven days of March from the 25th and the thirteenth the
  twenty-four before it. February has 28 days, and 29 in 2024.

  """

  use ExUnit.Case, async: true

  describe "month_numbers/1" do
    test "is one run from 1 in a calendar that is no composite" do
      assert Calendrical.Gregorian.month_numbers(2026) == [1..12]
      assert Calendrical.Hebrew.month_numbers(5786) == [1..12]
      assert Calendrical.Hebrew.month_numbers(5787) == [1..13]
      assert Calendrical.Coptic.month_numbers(1742) == [1..13]
      assert Calendrical.Julian.March25.month_numbers(1750) == [1..13]
    end

    test "is the months that have days in a year a composite calendar cut short" do
      assert Calendrical.Reform.England.month_numbers(1751) == [3..12]
      assert Calendrical.Reform.England.month_numbers(1752) == [1..12]
      assert Calendrical.Reform.England.month_numbers(1750) == [1..13]
    end

    test "is no month for a year the calendar does not have, or what is no year" do
      assert Calendrical.Reform.England.month_numbers(0) == []
      assert Calendrical.Gregorian.month_numbers(nil) == []
      assert Calendrical.Reform.England.month_numbers("1751") == []
    end
  end

  describe "day_numbers/2" do
    test "is one run from 1 in a calendar that is no composite" do
      assert Calendrical.Gregorian.day_numbers(2026, 2) == [1..28]
      assert Calendrical.Gregorian.day_numbers(2024, 2) == [1..29]
      assert Calendrical.Julian.March25.day_numbers(1750, 1) == [1..7]
      assert Calendrical.Julian.March25.day_numbers(1750, 13) == [1..24]
    end

    test "is the days that are dates in a month a composite calendar took days from" do
      assert Calendrical.Reform.England.day_numbers(1752, 9) == [1..2, 14..30]
      assert Calendrical.Reform.England.day_numbers(1751, 3) == [25..31]
      assert Calendrical.Reform.England.day_numbers(1760, 6) == [1..30]
    end

    test "is no day for a month the year does not have, or what is no month" do
      assert Calendrical.Gregorian.day_numbers(2026, 13) == []
      assert Calendrical.Gregorian.day_numbers(2026, 0) == []
      assert Calendrical.Reform.England.day_numbers(1751, 1) == []
      assert Calendrical.Gregorian.day_numbers(nil, 1) == []
      assert Calendrical.Reform.England.day_numbers(1751, "3") == []
    end
  end

  describe "a year a calendar cannot reckon" do
    # The Islamic calendars reckoned from the sky cover the years the
    # installed ephemeris does (1849 to 2150 CE), and 1750 AH is 2318 CE.
    # `months_in_year/1` and `days_in_month/2` raise for a year outside it.
    test "has no months and no days, and asking for them does not raise" do
      for calendar <- [Calendrical.Islamic.Rgsa, Calendrical.Islamic.Observational] do
        assert calendar.month_numbers(1446) == [1..12]
        assert [%Range{first: 1, last: last}] = calendar.day_numbers(1446, 1)
        assert last in 29..30

        assert calendar.month_numbers(1750) == []
        assert calendar.day_numbers(1750, 1) == []
        assert calendar.month_numbers(0) == []
        assert calendar.day_numbers(1446, 13) == []
        assert calendar.day_numbers(nil, 1) == []
      end
    end
  end

  describe "a calendar that is no composite" do
    # One of each way a calendar is made, and of each kind of year: by a
    # rule, by the moon and the sun, by the sky, in weeks, and counted from
    # another new-year day.
    @counted [
      Calendrical.Gregorian,
      Calendrical.Julian,
      Calendrical.Julian.March25,
      Calendrical.Hebrew,
      Calendrical.Coptic,
      Calendrical.Islamic.Civil,
      Calendrical.Persian,
      Calendrical.Chinese,
      Calendrical.ISOWeek,
      Calendrical.NRF
    ]

    test "numbers every year's months and every month's days from 1, and begins a year with them" do
      for calendar <- @counted, year <- years(calendar) do
        assert calendar.month_numbers(year) == [1..calendar.months_in_year(year)],
               "#{inspect(calendar)} #{year}"

        assert %Date.Range{first: %Date{year: ^year, month: 1, day: 1}} = calendar.year(year)
        assert calendar.day_of_year(year, 1, 1) == 1

        for month <- 1..calendar.months_in_year(year) do
          assert [%Range{first: 1, step: 1}] = calendar.day_numbers(year, month),
                 "#{inspect(calendar)} #{year}-#{month}"
        end
      end
    end
  end

  describe "every month and day a calendar numbers" do
    test "is a date, and no other day of the month is" do
      for calendar <- [Calendrical.Gregorian, Calendrical.Hebrew, Calendrical.Reform.England],
          year <- years(calendar),
          months <- calendar.month_numbers(year),
          month <- months do
        numbered = calendar.day_numbers(year, month) |> Enum.flat_map(&Enum.to_list/1)

        assert numbered != []

        for day <- 1..31 do
          assert calendar.valid_date?(year, month, day) == day in numbered,
                 "#{inspect(calendar)} #{year}-#{month}-#{day}"
        end
      end
    end
  end

  defp years(Calendrical.Hebrew), do: [5786, 5787]
  defp years(Calendrical.Reform.England), do: [1750, 1751, 1752, 1760]
  defp years(Calendrical.Julian.March25), do: [1750, 1751]
  defp years(Calendrical.Coptic), do: [1742, 1743]
  defp years(Calendrical.Islamic.Civil), do: [1447, 1448]
  defp years(Calendrical.Persian), do: [1404, 1405]
  defp years(Calendrical.Chinese), do: [4662, 4663]
  defp years(_calendar), do: [2024, 2026]
end
