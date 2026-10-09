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

    # Years and months are one shift, so the day is brought into the month
    # reached once, not into February 2025 on the way, as Calendar.ISO does.
    test "years and months together bring the day into the month reached once" do
      assert Date.shift(~D[2024-02-29 Calendrical.Reform.England], year: 1, month: 1) ==
               ~D[2025-03-29 Calendrical.Reform.England]

      assert Date.shift(~D[1752-01-25 Calendrical.Reform.Sweden], year: 1, month: 1) ==
               ~D[1753-02-17 Calendrical.Reform.Sweden]
    end

    test "a day beyond the month's last becomes its last day" do
      assert Date.shift(~D[1752-08-31 Calendrical.Reform.England], month: 1) ==
               ~D[1752-09-30 Calendrical.Reform.England]

      assert Date.shift(~D[1753-01-25 Calendrical.Reform.Sweden], month: 1) ==
               ~D[1753-02-17 Calendrical.Reform.Sweden]

      assert Date.shift(~D[1700-01-31 Calendrical.Reform.Sweden], month: 1) ==
               ~D[1700-02-28 Calendrical.Reform.Sweden]
    end

    test "months are the segments' own counted months" do
      # England's 1750 counts thirteen months from Lady Day: its month
      # 10 is the Julian December 1750 and its month 11 the Julian
      # January, both carrying the year 1750.
      assert Date.shift(~D[1750-10-10 Calendrical.Reform.England], month: 1) ==
               ~D[1750-11-10 Calendrical.Reform.England]

      # Twelve months on from month 11 pass through 1750's month 13 and
      # into the short year 1751, whose months are the Julian calendar's.
      assert Date.shift(~D[1750-11-10 Calendrical.Reform.England], month: 12) ==
               ~D[1751-12-10 Calendrical.Reform.England]

      assert Date.shift(~D[1751-04-10 Calendrical.Reform.England], month: -2) ==
               ~D[1750-13-10 Calendrical.Reform.England]

      # A month on from 1750's month 13 lands in 1751, which begins on
      # 25 March, its first day.
      assert Date.shift(~D[1750-13-10 Calendrical.Reform.England], month: 1) ==
               ~D[1751-03-25 Calendrical.Reform.England]
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

      # Russia's year reckoned from 1 March was cut short when the year
      # reckoned from 1 September began, on 1 September 1492: its counted
      # months 1 (March) to 6 (August), 184 days.
      assert Russia.year(1492) ==
               Date.range(~D[1492-01-01 Calendrical.Russia], ~D[1492-06-31 Calendrical.Russia])

      assert {England.days_in_year(1750), England.days_in_year(1751), England.days_in_year(1752)} ==
               {365, 282, 355}

      assert Russia.days_in_year(1492) == 184
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

    # A year has quarters where its counted months divide evenly into
    # them: England's thirteen-month Lady Day years have none, a year a
    # transition cuts short has none, and a whole twelve-month year has
    # its own, from whichever day it begins on.
    test "a year has quarters where its months divide into them" do
      assert England.quarter(1700, 1) == {:error, :not_defined}
      assert Russia.quarter(1492, 1) == {:error, :not_defined}

      # The March year 1400's first quarter is its months 1 to 3,
      # March to May, and the September year 1600's September to
      # November.
      assert Russia.quarter(1400, 1) ==
               Date.range(~D[1400-01-01 Calendrical.Russia], ~D[1400-03-31 Calendrical.Russia])

      assert Russia.quarter(1600, 1) ==
               Date.range(~D[1600-01-01 Calendrical.Russia], ~D[1600-03-30 Calendrical.Russia])

      assert Russia.quarter(1800, 1) ==
               Date.range(~D[1800-01-01 Calendrical.Russia], ~D[1800-03-31 Calendrical.Russia])
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

  describe "weeks" do
    # A year one member calendar governs throughout keeps that calendar's
    # weeks. A year a transition falls in or cuts short numbers the
    # composite's own calendar-aligned weeks, cut to the year.
    test "a year one calendar governs keeps that calendar's weeks" do
      assert England.week(2026, 1) ==
               Date.range(
                 ~D[2025-12-29 Calendrical.Reform.England],
                 ~D[2026-01-04 Calendrical.Reform.England]
               )
    end

    test "the week holding the dropped days runs across them" do
      # Wednesday 2 September 1752 was followed by Thursday 14 September
      week =
        Date.range(
          ~D[1752-08-31 Calendrical.Reform.England],
          ~D[1752-09-17 Calendrical.Reform.England]
        )

      assert Calendrical.Interval.week(~D[1752-09-02 Calendrical.Reform.England]) == week
      assert Calendrical.Interval.week(~D[1752-09-14 Calendrical.Reform.England]) == week
      assert Enum.count(week) == 7

      assert England.week_of_month(1752, 9, 14) == {9, 1}
      assert England.week_of_month(1752, 9, 18) == {9, 2}
    end

    test "every day of a transition year is in the week it numbers, and the weeks follow on" do
      for {calendar, year} <- [
            {England, 1751},
            {England, 1752},
            {Sweden, 1700},
            {Sweden, 1712},
            {Sweden, 1753},
            # Japan's last lunisolar year, which ended on 2 December 1228
            # (31 December 1872)
            {Japan, 1228},
            {Russia, 1918}
          ] do
        for day <- Calendrical.Interval.year(year, calendar) do
          {week_year, week} = Calendrical.week_of_year(day)
          iso_days = Date.to_gregorian_days(day)

          assert %Date.Range{first_in_iso_days: first, last_in_iso_days: last} =
                   Calendrical.Interval.week(week_year, week, calendar)

          assert first <= iso_days and iso_days <= last
        end

        {weeks, _days_in_last_week} = calendar.weeks_in_year(year)

        1..weeks
        |> Enum.map(&calendar.week(year, &1))
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [earlier, later] ->
          assert earlier.last_in_iso_days + 1 == later.first_in_iso_days
        end)

        assert {:error, :invalid_date} = calendar.week(year, weeks + 1)
      end
    end

    # England's 1155, the first Lady Day year, runs from 25 March 1155
    # to 24 March 1156, 366 days, and its weeks are counted over those
    # days alone: the days 1 January to 24 March 1155 have no dates and
    # no weeks.
    test "a year whose first day moved counts its weeks from that day" do
      assert {weeks_in_year, _days_in_last_week} = England.weeks_in_year(1155)

      assert England.week_of_year(1155, 1, 1) == {1155, 1}

      assert England.week(1155, 1).first == ~D[1155-01-01 Calendrical.Reform.England]

      assert England.week(1155, weeks_in_year).last ==
               ~D[1155-13-24 Calendrical.Reform.England]

      for week <- (weeks_in_year + 1)..(weeks_in_year + 3) do
        assert England.week(1155, week) == {:error, :invalid_date}, "week #{week}"
      end

      weeks = Enum.map(1..weeks_in_year, &England.week(1155, &1))

      weeks
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [earlier, later] -> assert Date.add(earlier.last, 1) == later.first end)

      for {week, number} <- Enum.with_index(weeks, 1), day <- week do
        assert England.week_of_year(day.year, day.month, day.day) == {1155, number}
      end
    end

    # In the test calendar of Russia 1700 is Peter the Great's January
    # year, Monday 1 January to Tuesday 31 December 1700, 366 Julian
    # days: 52 whole weeks and a week of two. The days 1 September to
    # 31 December 1699, which began the September year 1700, have no
    # dates and no weeks.
    test "a year whose first day moved back counts its weeks from the new first day" do
      # 1 January 1700 is eleven days on in the Gregorian calendar, a
      # Monday, and 31 December 1700 a Tuesday.
      assert Date.day_of_week(~D[1700-01-11]) == 1
      assert Date.day_of_week(~D[1701-01-11]) == 2

      assert Russia.weeks_in_year(1700) == {53, 2}
      assert Russia.week_of_year(1700, 1, 1) == {1700, 1}
      assert Russia.week_of_year(1700, 1, 7) == {1700, 1}
      assert Russia.week_of_year(1700, 1, 8) == {1700, 2}
      assert Russia.week_of_year(1700, 12, 31) == {1700, 53}

      assert Russia.week(1700, 1) ==
               Date.range(~D[1700-01-01 Calendrical.Russia], ~D[1700-01-07 Calendrical.Russia])

      assert Russia.week(1700, 53) ==
               Date.range(~D[1700-12-30 Calendrical.Russia], ~D[1700-12-31 Calendrical.Russia])

      assert Russia.week(1700, 54) == {:error, :invalid_date}
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
