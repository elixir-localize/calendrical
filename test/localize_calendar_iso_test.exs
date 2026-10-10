defmodule Calendrical.LocalizeCalendarISOTest do
  @moduledoc """
  Localize answers the Calendrical behaviour for `Calendar.ISO` in one
  module, `Localize.Calendar.ISO`, since `Calendar.ISO` has none of the
  behaviour's callbacks and Localize does not depend on Calendrical. Every
  question Localize puts about a `Calendar.ISO` date goes to that module, so
  this test holds it to the behaviour: it answers every callback, and it
  answers as `Calendrical.ISO` does, the proleptic Gregorian calendar with
  ISO 8601's weeks.

  A required callback added to the behaviour fails the first test until
  Localize answers it for `Calendar.ISO` too; an optional callback, such
  as the lunisolar family's, is one callers tolerate the absence of.

  """

  use ExUnit.Case, async: true

  @localize Localize.Calendar.ISO
  @calendrical Calendrical.ISO

  # Eight years and their neighbours: every weekday a year can begin on,
  # leap years among them.
  @days Date.range(~D[2019-12-25], ~D[2028-01-07])
  @years 2015..2032

  @date_parts [:years, :quarters, :months, :weeks, :days]

  describe "Localize.Calendar.ISO" do
    test "answers every required callback of the Calendrical behaviour" do
      Code.ensure_loaded!(@localize)

      required =
        Calendrical.behaviour_info(:callbacks) --
          Calendrical.behaviour_info(:optional_callbacks)

      missing =
        for {name, arity} <- required,
            not function_exported?(@localize, name, arity),
            do: {name, arity}

      assert missing == []
    end

    test "answers every callback of the Calendar behaviour" do
      Code.ensure_loaded!(@localize)

      missing =
        for {name, arity} <- Calendar.behaviour_info(:callbacks),
            not function_exported?(@localize, name, arity),
            do: {name, arity}

      assert missing == []
    end
  end

  describe "Localize.Calendar.ISO answers as Calendrical.ISO does" do
    test "for a date" do
      callbacks = [
        :month_of_year,
        :cardinal_day,
        :numeric_month,
        :week_of_year,
        :iso_week_of_year,
        :week_of_month,
        :calendar_year,
        :extended_year,
        :related_gregorian_year,
        :cyclic_year
      ]

      mismatches =
        for date <- @days,
            callback <- callbacks,
            arguments = [date.year, date.month, date.day],
            localize = apply(@localize, callback, arguments),
            calendrical = apply(@calendrical, callback, arguments),
            localize != calendrical,
            do: {callback, date, localize, calendrical}

      assert mismatches == []
    end

    test "for a year" do
      for year <- @years do
        for callback <- [
              :periods_in_year,
              :weeks_in_year,
              :days_in_year,
              :traditional_months,
              :leap_month,
              :traditional_leap_month
            ] do
          assert apply(@localize, callback, [year]) == apply(@calendrical, callback, [year]),
                 "#{callback}(#{year})"
        end

        assert days(@localize.year(year)) == days(@calendrical.year(year))
      end
    end

    # A month the year does not have, 0 or 13, a week a month does not
    # have and a day a year does not have are the same answer from both.
    test "for the months of a year, their weeks and the days of a year" do
      for year <- @years, month <- 0..13 do
        for callback <- [:lunar_month_of_year, :ordinal_month_from_traditional, :weeks_in_month] do
          assert apply(@localize, callback, [year, month]) ==
                   apply(@calendrical, callback, [year, month]),
                 "#{callback}(#{year}, #{month})"
        end

        assert Enum.map(@localize.named_month(year, month), &days/1) ==
                 Enum.map(@calendrical.named_month(year, month), &days/1),
               "named_month(#{year}, #{month})"

        for week <- 0..6 do
          assert days(@localize.month_week(year, month, week)) ==
                   days(@calendrical.month_week(year, month, week)),
                 "month_week(#{year}, #{month}, #{week})"
        end
      end

      for year <- @years, day <- [0, 1, 59, 60, 365, 366, 367] do
        assert day_number(@localize.date_from_day_of_year(year, day)) ==
                 day_number(@calendrical.date_from_day_of_year(year, day)),
               "date_from_day_of_year(#{year}, #{day})"
      end
    end

    # A period the year does not have, quarter 0 or 5, month 13 or week 54,
    # is the same error from both.
    test "for the periods of a year" do
      periods = [quarter: 0..5, quadrimester: 0..4, semester: 0..3, month: 0..13, week: 0..54]

      for year <- @years, {callback, numbers} <- periods, number <- numbers do
        assert days(apply(@localize, callback, [year, number])) ==
                 days(apply(@calendrical, callback, [year, number])),
               "#{callback}(#{year}, #{number})"
      end
    end

    test "without a year" do
      assert @localize.calendar_base() == @calendrical.calendar_base()
      assert @localize.cldr_calendar_type() == @calendrical.cldr_calendar_type()
      assert @localize.era_calendar_type() == @calendrical.era_calendar_type()
      assert @localize.months_in_year() == @calendrical.months_in_year()

      for month <- 0..13 do
        assert @localize.days_in_month(month) == @calendrical.days_in_month(month)
      end

      for month <- 1..12 do
        assert @localize.cardinal_month(month) == @calendrical.cardinal_month(month)
      end
    end

    # Each reads a written date as a date of its own.
    test "for the calendar a written date is parsed in" do
      assert @localize.parsing_calendar() == Calendar.ISO
      assert @calendrical.parsing_calendar() == Calendrical.ISO
    end

    test "for the dates of a month and day in a Gregorian year" do
      for year <- [2023, 2024], {month, day} <- [{2, 28}, {2, 29}, {12, 31}, {4, 31}, {13, 1}] do
        assert fields(@localize.dates_in_gregorian_year(year, month, day)) ==
                 fields(@calendrical.dates_in_gregorian_year(year, month, day)),
               "#{year}-#{month}-#{day}"
      end
    end

    test "adding years, quarters, months, weeks and days" do
      mismatches =
        for date <- Enum.take_every(@days, 5),
            date_part <- @date_parts,
            count <- [-400, -25, -13, -12, -1, 0, 1, 2, 11, 12, 13, 25, 400],
            coerce <- [true, false],
            arguments = [date.year, date.month, date.day, date_part, count, [coerce: coerce]],
            localize = apply(@localize, :plus, arguments),
            calendrical = apply(@calendrical, :plus, arguments),
            localize != calendrical,
            do: {arguments, localize, calendrical}

      assert mismatches == []
    end

    test "counting the years, quarters, months, weeks and days between two dates" do
      gaps = [-800, -400, -366, -365, -62, -31, -30, -29, -28, -1, 0, 1, 27, 28, 29, 30, 31, 59]
      gaps = gaps ++ [62, 365, 366, 400, 800]

      mismatches =
        for from <- Enum.take_every(@days, 5),
            gap <- gaps,
            date_part <- @date_parts,
            arguments = [Date.to_erl(from), Date.to_erl(Date.add(from, gap)), date_part],
            localize = apply(@localize, :diff, arguments),
            calendrical = apply(@calendrical, :diff, arguments),
            localize != calendrical,
            do: {arguments, localize, calendrical}

      assert mismatches == []
    end
  end

  # A range of days by its first and last, whichever calendar names them.
  defp day_number(%Date{} = date), do: Date.to_gregorian_days(date)
  defp day_number(error), do: error

  defp days(%Date.Range{first: first, last: last}), do: {fields(first), fields(last)}
  defp days(error), do: error

  defp fields(dates) when is_list(dates), do: Enum.map(dates, &fields/1)
  defp fields(%Date{year: year, month: month, day: day}), do: {year, month, day}
end
