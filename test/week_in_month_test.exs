defmodule Calendrical.WeekInMonth.Test do
  use ExUnit.Case, async: true
  import Calendrical.Helper

  # `Calendar.ISO` dates are counted in `Calendrical.Gregorian`, whose weeks
  # begin on Monday and whose week 1 of a month is the week holding the
  # month's first day, so the days before it in that week are in the new
  # month's week 1, as they are in the new year's.
  test "Week in month for gregorian dates, whose weeks begin on Monday" do
    assert Calendrical.week_of_month(~D[2019-01-01]) == {1, 1}
    assert Calendrical.week_of_month(~D[2018-12-31]) == {1, 1}
    assert Calendrical.week_of_month(~D[2019-12-30]) == {1, 1}

    # December 2019's week 1 runs from Monday 25 November to Sunday 1 December
    assert Calendrical.week_of_month(~D[2019-11-24]) == {11, 4}
    assert Calendrical.week_of_month(~D[2019-11-25]) == {12, 1}
    assert Calendrical.week_of_month(~D[2019-12-28]) == {12, 5}

    # January 1995 begins on a Sunday, so its week 1 begins on 26 December
    # 1994 and Monday 23 January begins its week 5
    assert Calendrical.week_of_month(~D[1995-01-23]) == {1, 5}
    assert Calendrical.week_of_month(~D[1995-01-30]) == {2, 1}
  end

  # `Calendrical.ISO` keeps ISO 8601's rule: a month's week 1 is the first
  # week holding four or more of its days.
  test "Week in month for the ISO calendar" do
    # The week from Monday 27 September 2021 holds three days of October
    assert Calendrical.week_of_month(~D[2021-10-01 Calendrical.ISO]) == {9, 5}
    assert Calendrical.week_of_month(~D[2021-10-03 Calendrical.ISO]) == {9, 5}
    assert Calendrical.week_of_month(~D[2021-10-04 Calendrical.ISO]) == {10, 1}

    # The week from Monday 30 December 2019 holds five days of January
    assert Calendrical.week_of_month(~D[2019-12-30 Calendrical.ISO]) == {1, 1}
  end

  test "Week in month for gregorian dates with first week starting on January 1st" do
    assert Calendrical.week_of_month(date(2019, 01, 01, Calendrical.BasicWeek)) == {1, 1}
    assert Calendrical.week_of_month(date(2018, 12, 31, Calendrical.BasicWeek)) == {12, 5}
    assert Calendrical.week_of_month(date(2019, 12, 30, Calendrical.BasicWeek)) == {12, 5}
    assert Calendrical.week_of_month(date(2019, 12, 28, Calendrical.BasicWeek)) == {12, 4}

    assert Calendrical.week_of_month(date(2019, 04, 01, Calendrical.BasicWeek)) == {4, 1}
    assert Calendrical.week_of_month(date(2019, 04, 07, Calendrical.BasicWeek)) == {4, 1}
    assert Calendrical.week_of_month(date(2019, 04, 08, Calendrical.BasicWeek)) == {4, 2}
  end

  test "Week 53 of a long year belongs to month 12, never month 13" do
    # Gregorian's weeks: 2017 and 2023 are long years, and their last days
    # are in December's week 5.
    assert Calendrical.week_of_year(~D[2017-12-31]) == {2017, 53}
    assert Calendrical.week_of_month(~D[2017-12-28]) == {12, 5}
    assert Calendrical.week_of_month(~D[2017-12-31]) == {12, 5}
    assert Calendrical.week_of_month(~D[2023-12-31]) == {12, 5}

    # The week-calendar path agrees: ISO year 2015 is a long year and
    # ISOWeek has the default 4, 5, 4 configuration, so month 12
    # spans weeks 49 to 53.
    assert Calendrical.week_of_month(date(2015, 53, 1, Calendrical.ISOWeek)) == {12, 5}
  end

  test "Week in month for ISOWeek which has a 4, 5, 4 configuration" do
    assert Calendrical.week_of_month(date(2019, 01, 1, Calendrical.ISOWeek)) == {1, 1}
    assert Calendrical.week_of_month(date(2018, 04, 1, Calendrical.ISOWeek)) == {1, 4}
    assert Calendrical.week_of_month(date(2019, 05, 1, Calendrical.ISOWeek)) == {2, 1}
    assert Calendrical.week_of_month(date(2019, 12, 1, Calendrical.ISOWeek)) == {3, 3}
    assert Calendrical.week_of_month(date(2019, 13, 1, Calendrical.ISOWeek)) == {3, 4}
    assert Calendrical.week_of_month(date(2019, 14, 1, Calendrical.ISOWeek)) == {4, 1}
  end

  describe "TR35's weeks of a month" do
    test "for every first day of the week and minimum days in the first week" do
      for first_day <- 1..7, min_days <- 1..7 do
        {:ok, calendar} =
          Calendrical.new(
            Module.concat(__MODULE__, "Day#{first_day}Min#{min_days}"),
            :month,
            day_of_week: first_day,
            min_days_in_first_week: min_days
          )

        assert misnumbered(calendar, first_day, min_days, ~D[2020-01-01], ~D[2020-12-31]) == []
      end
    end

    test "for fiscal years" do
      for {calendar, first_day, min_days} <- [
            {Calendrical.Fiscal.US, 7, 4},
            {Calendrical.Fiscal.UK, 1, 1},
            {Calendrical.Fiscal.AU, 1, 1}
          ] do
        assert misnumbered(calendar, first_day, min_days, ~D[2019-01-01], ~D[2020-12-31]) == []
      end
    end

    # ISO 8601's rule in closed form: a week is the month's that holds its
    # Thursday, and is that month's week `div(day - 1, 7) + 1` for the
    # Thursday's day of the month.
    test "for ISO 8601, the month of the week's Thursday" do
      for date <- Date.range(~D[2015-01-01], ~D[2026-12-31]) do
        thursday = Date.add(date, 4 - Date.day_of_week(date))

        assert Calendrical.ISO.week_of_month(date.year, date.month, date.day) ==
                 {thursday.month, div(thursday.day - 1, 7) + 1}
      end
    end
  end

  # The days from `first` to `last` whose week of the month in `calendar`
  # is not the one TR35's rule gives.
  defp misnumbered(calendar, first_day, min_days, first, last) do
    for date <- Date.range(first, last),
        expected =
          expected_week_of_month(Date.to_gregorian_days(date), calendar, first_day, min_days),
        %{year: year, month: month, day: day} = Date.convert!(date, calendar),
        calendar.week_of_month(year, month, day) != expected,
        do: {date, expected}
  end

  # TR35's rule, by counting: the week holding a day, beginning on the
  # calendar's first day of the week, is the later month's when it holds
  # `min_days` or more of that month's days and otherwise the earlier
  # month's, and its number counts back through the weeks holding
  # `min_days` or more of that month's days.
  defp expected_week_of_month(gregorian_days, calendar, first_day, min_days) do
    start = Enum.find((gregorian_days - 6)..gregorian_days, &(day_of_week(&1) == first_day))
    months = start..(start + 6) |> Enum.map(&month_of(&1, calendar)) |> Enum.uniq()

    month =
      case months do
        [month] ->
          month

        [earlier, later] ->
          if days_in(start, later, calendar) >= min_days, do: later, else: earlier
      end

    weeks_before =
      Stream.iterate(start - 7, &(&1 - 7))
      |> Enum.take_while(&(days_in(&1, month, calendar) >= min_days))
      |> length()

    {elem(month, 1), weeks_before + 1}
  end

  defp days_in(start, month, calendar) do
    Enum.count(start..(start + 6), &(month_of(&1, calendar) == month))
  end

  defp month_of(gregorian_days, calendar) do
    date = gregorian_days |> Date.from_gregorian_days() |> Date.convert!(calendar)
    {date.year, date.month}
  end

  defp day_of_week(gregorian_days) do
    gregorian_days |> Date.from_gregorian_days() |> Date.day_of_week()
  end
end
