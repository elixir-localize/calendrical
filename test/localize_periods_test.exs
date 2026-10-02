defmodule Calendrical.LocalizePeriodsTest do
  @moduledoc """
  Localize counts the periods between two dates by asking the dates'
  calendar: the years, quarters and months of a relative time and the years,
  months and days of a duration come from the calendar's `diff/3` and
  `plus/6`, and two dates are ordered by its days. Localize cannot load
  Calendrical, so its counting in Calendrical's calendars is held to the
  calendars' own answers here.

  Neither oracle uses Localize's arithmetic. A relative time is checked by
  walking the days between the two dates and counting the times the
  calendar's own answer for a day changes: its year, its quarter of the year
  and its month of the year. A duration is checked with `Date.shift/2`, the
  calendar's own `shift_date/4`: added to the earlier date it is the later,
  and a year or a month more would pass it.

  """

  use ExUnit.Case, async: true

  @calendars [
    Calendrical.Gregorian,
    Calendrical.Julian,
    Calendrical.Julian.March1,
    Calendrical.Julian.March25,
    Calendrical.Julian.Sept1,
    Calendrical.Julian.Dec25,
    Calendrical.Hebrew,
    Calendrical.Islamic.Civil,
    Calendrical.Coptic,
    Calendrical.Japanese,
    Calendrical.ISOWeek,
    Calendrical.NRF
  ]

  # Calendars whose months are astronomy, and slow to count: they run with
  # `--include full`, as CI does.
  @astronomical [Calendrical.Persian, Calendrical.Chinese]

  # The Julian calendar has no year 0, and its variants turn the year on
  # other days than 1 January, so their years are counted around 1 BC too.
  @julian [
    Calendrical.Julian,
    Calendrical.Julian.March1,
    Calendrical.Julian.March25,
    Calendrical.Julian.Sept1,
    Calendrical.Julian.Dec25
  ]

  @gaps [-800, -400, -366, -365, -92, -62, -31, -30, -1, 0, 1, 27, 28, 29, 30, 31, 32] ++
          [59, 61, 91, 180, 354, 355, 365, 366, 384, 400, 800]

  @units [:year, :quarter, :month, :week]

  describe "a relative time counts the calendar's own periods" do
    test "between 2023 and 2027 in every kind of calendar" do
      for calendar <- @calendars do
        assert mismatches(calendar, ~D[2023-01-01], ~D[2027-12-31], 61) == [], inspect(calendar)
      end
    end

    @tag :full
    test "between 2023 and 2027 in the astronomical calendars" do
      for calendar <- @astronomical do
        assert mismatches(calendar, ~D[2023-01-01], ~D[2027-12-31], 61) == [], inspect(calendar)
      end
    end

    test "across 1 BC and AD 1 in the Julian calendars, which have no year 0" do
      for calendar <- @julian do
        assert mismatches(calendar, ~D[-0001-06-01], ~D[0002-06-30], 37) == [], inspect(calendar)
      end
    end

    # 1 January of a year reckoned from 25 March is the day after 31 December
    # of the same year, and 25 March the day after 24 March of the year
    # before: in the same month and the next year.
    test "where a year turns after its first month, and within one" do
      calendar = Calendrical.Julian.March25
      december = Date.new!(2022, 12, 31, calendar)
      january = Date.new!(2022, 1, 1, calendar)
      last_day = Date.new!(2022, 3, 24, calendar)
      new_year = Date.new!(2023, 3, 25, calendar)

      assert Date.diff(january, december) == 1
      assert Date.diff(new_year, last_day) == 1

      for {relative, relative_to, unit, expected} <- [
            {january, december, nil, "tomorrow"},
            {january, december, :month, "next month"},
            {january, december, :year, "this year"},
            {december, january, nil, "yesterday"},
            {december, january, :month, "last month"},
            {new_year, last_day, nil, "tomorrow"},
            {new_year, last_day, :month, "this month"},
            {new_year, last_day, :quarter, "next quarter"},
            {new_year, last_day, :year, "next year"},
            {last_day, new_year, :year, "last year"}
          ] do
        assert Localize.DateTime.Relative.to_string(relative,
                 relative_to: relative_to,
                 unit: unit,
                 locale: :en
               ) == {:ok, expected},
               "#{inspect(relative)} against #{inspect(relative_to)} in #{inspect(unit)}"
      end
    end
  end

  describe "a duration is counted by the calendar" do
    test "added to the earlier date it is the later, with the most of each unit" do
      for calendar <- @calendars, do: assert_durations_add_back(calendar)
    end

    @tag :full
    test "added to the earlier date it is the later in the astronomical calendars" do
      for calendar <- @astronomical, do: assert_durations_add_back(calendar)
    end

    # 31 December 2022 to 1 January 2022 is a day in a year reckoned from 25
    # March, and from the year's first day to its last, 25 March 2022 to 24
    # March of the next Julian year, is eleven months, to 25 February, and
    # 27 days: 2023 is not a leap year.
    test "where the dates' fields are not in the order of their days" do
      calendar = Calendrical.Julian.March25

      assert {:ok, %{year: 0, month: 0, day: 1}} =
               Localize.Duration.new(
                 Date.new!(2022, 12, 31, calendar),
                 Date.new!(2022, 1, 1, calendar)
               )

      assert {:ok, %{year: 0, month: 11, day: 27}} =
               Localize.Duration.new(
                 Date.new!(2022, 3, 25, calendar),
                 Date.new!(2022, 3, 24, calendar)
               )

      assert {:error, %ArgumentError{}} =
               Localize.Duration.new(
                 Date.new!(2022, 1, 1, calendar),
                 Date.new!(2022, 12, 31, calendar)
               )
    end

    # A calendar of weeks' months are its periods of weeks, and a Hebrew leap
    # year has thirteen months: neither is twelve months of the month field.
    test "in a calendar of weeks and across a Hebrew leap year" do
      week = Date.new!(2026, 25, 2, Calendrical.ISOWeek)

      assert {:ok, %{year: 1, month: 0, day: 0}} =
               Localize.Duration.new(week, Date.new!(2027, 25, 2, Calendrical.ISOWeek))

      # 5784 is a leap year of thirteen months, so 1 Tishri 5784 to 1 Tishri
      # 5785 is a year, and to the day before it twelve months and 28 days:
      # Elul, the month before Tishri, has 29.
      tishri = Date.new!(5784, 1, 1, Calendrical.Hebrew)
      next_tishri = Date.new!(5785, 1, 1, Calendrical.Hebrew)

      assert Calendrical.Hebrew.months_in_year(5784) == 13
      assert {:ok, %{year: 1, month: 0, day: 0}} = Localize.Duration.new(tishri, next_tishri)

      assert {:ok, %{year: 0, month: 12, day: 28}} =
               Localize.Duration.new(tishri, Date.add(next_tishri, -1))
    end
  end

  # Every duration between two dates of the calendar has no negative part,
  # is the span `Date.shift/2` adds to the earlier date to reach the later,
  # and holds the most years, and then the most months, that do not pass it.
  defp assert_durations_add_back(calendar) do
    for from_iso <- Enum.take_every(Date.range(~D[2023-01-01], ~D[2026-12-31]), 61),
        gap <- @gaps,
        gap >= 0 do
      from = Date.convert!(from_iso, calendar)
      to = Date.convert!(Date.add(from_iso, gap), calendar)

      assert {:ok, duration} = Localize.Duration.new(from, to),
             "#{inspect(from)} to #{inspect(to)}"

      %{year: years, month: months, day: days} = duration

      assert years >= 0 and months >= 0 and days >= 0,
             "#{inspect(from)} to #{inspect(to)}: #{inspect({years, months, days})}"

      assert Date.shift(from, year: years, month: months, day: days) == to,
             "#{inspect(from)} to #{inspect(to)}: #{inspect({years, months, days})}"

      assert Date.diff(Date.shift(from, year: years + 1), to) > 0,
             "#{inspect(from)} to #{inspect(to)}: another year fits"

      assert Date.diff(Date.shift(from, year: years, month: months + 1), to) > 0,
             "#{inspect(from)} to #{inspect(to)}: another month fits"
    end
  end

  # The pairs of dates whose relative time, in years, quarters, months and
  # weeks, is not the count of the calendar's own periods between them.
  defp mismatches(calendar, first, last, step) do
    days = answers(calendar, Date.add(first, -801), Date.add(last, 801))

    for from_iso <- Enum.take_every(Date.range(first, last), step),
        gap <- @gaps,
        to_iso = Date.add(from_iso, gap),
        {from, from_counts} = Map.fetch!(days, from_iso),
        {to, to_counts} = Map.fetch!(days, to_iso),
        unit <- @units,
        count = Map.fetch!(to_counts, unit) - Map.fetch!(from_counts, unit),
        expected = Localize.DateTime.Relative.to_string(count, unit: unit, locale: :en),
        actual =
          Localize.DateTime.Relative.to_string(to, relative_to: from, unit: unit, locale: :en),
        actual != expected do
      {from, to, unit, expected, actual}
    end
  end

  # Every day of a span in the calendar, with the number of times each of
  # the calendar's answers has changed since the span's first day. A week
  # turns on Sunday, the first day of the week in `en` (CLDR's weekData).
  defp answers(calendar, first, last) do
    {rows, _previous} =
      Enum.map_reduce(Date.range(first, last), nil, fn iso, previous ->
        date = Date.convert!(iso, calendar)

        answers = %{
          year: date.year,
          quarter: Date.quarter_of_year(date),
          month: calendar.month_of_year(date.year, date.month, date.day),
          week: Date.day_of_week(iso, :sunday) == 1
        }

        counts =
          case previous do
            nil ->
              %{year: 0, quarter: 0, month: 0, week: 0}

            {earlier, counts} ->
              %{
                year: counts.year + changed(answers.year, earlier.year),
                quarter: counts.quarter + changed(answers.quarter, earlier.quarter),
                month: counts.month + changed(answers.month, earlier.month),
                week: counts.week + if(answers.week, do: 1, else: 0)
              }
          end

        {{iso, {date, counts}}, {answers, counts}}
      end)

    Map.new(rows)
  end

  defp changed(answer, answer), do: 0
  defp changed(_answer, _earlier), do: 1
end
