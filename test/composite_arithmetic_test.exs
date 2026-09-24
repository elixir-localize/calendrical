defmodule Calendrical.CompositeArithmetic.Test do
  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Japan, Sweden}
  alias Calendrical.Russia

  describe "month arithmetic across a transition" do
    test "a month after a date keeps the day when the new month has it" do
      assert Date.shift(~D[1752-08-20 Calendrical.Reform.England], month: 1) ==
               ~D[1752-09-20 Calendrical.Reform.England]

      assert Date.shift(~D[1752-10-20 Calendrical.Reform.England], month: -1) ==
               ~D[1752-09-20 Calendrical.Reform.England]
    end

    test "a day the transition removed becomes the month's next day that exists" do
      assert Date.shift(~D[1752-08-05 Calendrical.Reform.England], month: 1) ==
               ~D[1752-09-14 Calendrical.Reform.England]

      assert Date.shift(~D[1918-01-10 Calendrical.Russia], month: 1) ==
               ~D[1918-02-14 Calendrical.Russia]
    end

    test "a day beyond the month's last becomes its last day" do
      assert Date.shift(~D[1752-08-31 Calendrical.Reform.England], month: 1) ==
               ~D[1752-09-30 Calendrical.Reform.England]

      assert Date.shift(~D[1753-01-25 Calendrical.Reform.Sweden], month: 1) ==
               ~D[1753-02-17 Calendrical.Reform.Sweden]

      assert Date.shift(~D[1700-01-31 Calendrical.Reform.Sweden], month: 1) ==
               ~D[1700-02-28 Calendrical.Reform.Sweden]
    end

    test "months are counted from January whatever the year's first day" do
      # December 1750 and January 1751 both carry the year 1750 in England
      assert Date.shift(~D[1750-12-10 Calendrical.Reform.England], month: 1) ==
               ~D[1750-01-10 Calendrical.Reform.England]

      assert Date.shift(~D[1750-01-10 Calendrical.Reform.England], month: 12) ==
               ~D[1752-01-10 Calendrical.Reform.England]

      assert Date.shift(~D[1751-04-10 Calendrical.Reform.England], month: -2) ==
               ~D[1750-02-10 Calendrical.Reform.England]
    end

    test "a lunisolar segment gives way to the Gregorian calendar" do
      last_lunisolar_day = Date.shift(~D[1873-01-01 Calendrical.Reform.Japan], day: -1)
      assert Japan.days_in_month(last_lunisolar_day.year, last_lunisolar_day.month) == 2

      month_before = Date.shift(last_lunisolar_day, month: -1)
      assert Date.shift(month_before, month: 1) == last_lunisolar_day
      assert Date.shift(month_before, month: 2).year == 1873
    end

    test "every shift around a transition is a valid date" do
      for {calendar, around} <- [
            {England, ~D[1752-09-14]},
            {England, ~D[1751-03-25]},
            {Sweden, ~D[1753-03-01]},
            {Sweden, ~D[1700-03-11]},
            {Russia, ~D[1918-02-14]},
            {Russia, ~D[1700-01-11]}
          ],
          offset <- -400..400//7,
          shift <- [1, -1, 13, -13] do
        date = around |> Date.add(offset) |> Date.convert!(calendar)
        shifted = Date.shift(date, month: shift)
        assert calendar.valid_date?(shifted.year, shifted.month, shifted.day)
      end
    end
  end

  describe "plus/6" do
    test "adds every date part" do
      assert England.plus(2020, 1, 1, :days, 1) == {2020, 1, 2}
      assert England.plus(2020, 1, 1, :weeks, 1) == {2020, 1, 8}
      assert England.plus(2020, 1, 1, :months, 1) == {2020, 2, 1}
      assert England.plus(2020, 1, 1, :quarters, 1) == {2020, 4, 1}
      assert England.plus(2020, 2, 29, :years, 1) == {2021, 2, 28}
    end

    test "a date and time shift crosses the gap" do
      {:ok, date_time} = NaiveDateTime.new(1752, 9, 2, 10, 0, 0, {0, 0}, England)

      assert NaiveDateTime.shift(date_time, day: 1) ==
               ~N[1752-09-14 10:00:00 Calendrical.Reform.England]
    end
  end

  describe "years, quarters and months" do
    test "a year runs from whichever day it begins on" do
      assert England.year(1751) ==
               Date.range(
                 ~D[1751-03-25 Calendrical.Reform.England],
                 ~D[1751-12-31 Calendrical.Reform.England]
               )

      assert Russia.year(1699) ==
               Date.range(~D[1699-09-01 Calendrical.Russia], ~D[1699-12-31 Calendrical.Russia])

      assert {England.days_in_year(1750), England.days_in_year(1751), England.days_in_year(1752)} ==
               {365, 282, 355}

      assert Russia.days_in_year(1699) == 122
    end

    test "the day of the year counts the days that carry the year" do
      assert England.day_of_year(1751, 3, 25) == 1
      assert England.day_of_year(1752, 9, 14) == 247
      assert England.day_of_year(1752, 12, 31) == 355
    end

    test "a year no segment labels has no days" do
      assert Japan.days_in_year(1500) == 0
      assert {:error, :invalid_date} = Japan.year(1500)
    end

    test "a quarter runs across the dropped days" do
      assert England.quarter(1752, 3) ==
               Date.range(
                 ~D[1752-07-01 Calendrical.Reform.England],
                 ~D[1752-09-30 Calendrical.Reform.England]
               )
    end

    test "a month cut short by a transition ends on its last day" do
      assert Sweden.days_in_month(1700, 2) == 28
      assert Sweden.days_in_month(1753, 2) == 17

      assert Date.end_of_month(~D[1753-02-10 Calendrical.Reform.Sweden]) ==
               ~D[1753-02-17 Calendrical.Reform.Sweden]

      assert Sweden.month(1753, 2) ==
               Date.range(
                 ~D[1753-02-01 Calendrical.Reform.Sweden],
                 ~D[1753-02-17 Calendrical.Reform.Sweden]
               )

      assert Russia.month(1918, 2) ==
               Date.range(~D[1918-02-14 Calendrical.Russia], ~D[1918-02-28 Calendrical.Russia])
    end

    test "a month counts the months of the calendar in effect" do
      leap_year = Enum.find(1200..1228, &(Calendrical.LunarJapanese.months_in_year(&1) == 13))
      assert Japan.months_in_year(leap_year) == 13
    end
  end

  describe "localization and formatting" do
    test "a composite date's month is localized" do
      assert Calendrical.localize(~D[1752-09-20 Calendrical.Reform.England], :month, locale: :en) ==
               "Sep"
    end

    test "a composite year is formatted" do
      assert is_binary(Calendrical.Format.year(1752, calendar: England))
      assert is_binary(Calendrical.Format.month(1752, 9, calendar: England))
    end
  end
end
