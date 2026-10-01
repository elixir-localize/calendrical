defmodule Calendrical.CalendarContract.Test do
  @moduledoc """
  The calendar contract, checked for every calendar module in the library: a
  date in each calendar answers the `Calendar` and `Calendrical` questions
  without raising, and invalid arguments are errors rather than crashes.

  """

  use ExUnit.Case, async: true

  {:ok, modules} = :application.get_key(:calendrical, :modules)

  @sighting_calendars [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa]

  # The callbacks that answer a question about a date, with the arguments
  # after its year, month and day.
  @date_callbacks [
    day_of_week: [:default],
    day_of_week: [:monday],
    day_of_year: [],
    day_of_era: [],
    year_of_era: [],
    quarter_of_year: [],
    month_of_year: [],
    week_of_year: [],
    iso_week_of_year: [],
    week_of_month: [],
    calendar_year: [],
    extended_year: [],
    related_gregorian_year: [],
    cyclic_year: []
  ]

  @calendars for module <- Enum.sort(modules),
                 Code.ensure_loaded?(module),
                 function_exported?(module, :valid_date?, 3),
                 function_exported?(module, :naive_datetime_from_iso_days, 1),
                 do: module

  for calendar <- @calendars do
    describe "#{inspect(calendar)}" do
      setup do
        {:ok, date: Date.convert!(~D[2025-06-15], unquote(calendar))}
      end

      test "valid_date?/3 is false for parts that are not a date", %{date: date} do
        calendar = unquote(calendar)

        for {year, month, day} <- [
              {nil, 1, 1},
              {date.year, nil, 1},
              {date.year, 1, "1"},
              {date.year, 0, 1},
              {date.year, 1, 0},
              {date.year, -1, -1}
            ] do
          refute calendar.valid_date?(year, month, day)
        end
      end

      # A question about a date the calendar does not have is an error,
      # never a raise nor an answer for some other date.
      test "a date the calendar does not have is an error in every date callback",
           %{date: date} do
        calendar = unquote(calendar)

        impossible =
          for {year, month, day} <- [
                {date.year, 0, 1},
                {date.year, 1, 0},
                {date.year, 99, 1},
                {date.year, 1, 99},
                {date.year, -1, -1}
              ],
              not calendar.valid_date?(year, month, day),
              do: {year, month, day}

        assert impossible != []

        for {year, month, day} <- impossible ++ [{date.year, "1", 1}, {date.year, 1, :""}],
            {callback, extra} <- @date_callbacks,
            function_exported?(calendar, callback, 3 + length(extra)) do
          assert apply(calendar, callback, [year, month, day | extra]) == {:error, :invalid_date},
                 "#{callback}#{inspect([year, month, day | extra])}"
        end
      end

      # A date missing a field is answered as a partial date where the
      # callback can answer one, and is otherwise an error, never a raise.
      test "a date missing a field never raises in a date callback", %{date: date} do
        calendar = unquote(calendar)

        for {year, month, day} <- [{nil, 1, 1}, {date.year, nil, 1}, {date.year, 1, nil}],
            {callback, extra} <- @date_callbacks,
            function_exported?(calendar, callback, 3 + length(extra)) do
          apply(calendar, callback, [year, month, day | extra])
        end
      end

      test "a period the year does not have is an error", %{date: date} do
        calendar = unquote(calendar)

        for month <- [0, 99], do: assert({:error, _} = calendar.month(date.year, month))
        for quarter <- [0, 5], do: assert({:error, _} = calendar.quarter(date.year, quarter))
        assert {:error, _} = calendar.week(date.year, 99)
      end

      test "a month of the year names a month of the CLDR calendar", %{date: date} do
        calendar = unquote(calendar)

        month =
          case calendar.month_of_year(date.year, date.month, date.day) do
            {month, _leap} -> month
            month -> month
          end

        assert calendar.cardinal_month(month) in 1..13
      end

      test "its eras are named by a CLDR calendar" do
        assert unquote(calendar).era_calendar_type() in Localize.Calendar.known_calendars()
      end

      # A calendar of weeks has no month or day of the month of its own,
      # so a written date is read as a Gregorian one; any other calendar
      # reads its own.
      test "its written dates are parsed in itself, or as Gregorian for a calendar of weeks" do
        expected =
          Map.fetch!(
            %{week: Calendar.ISO, month: unquote(calendar)},
            unquote(calendar).calendar_base()
          )

        assert unquote(calendar).parsing_calendar() == expected
      end

      # Localize reads a calendar of weeks' dates back as the calendar writes
      # them, through `parse_date/1`, so a calendar reads back the date it
      # writes, and answers text that is no date, or no date it has, with an
      # error, never a raise.
      test "its parse callbacks read back what it writes and answer anything else with an error",
           %{date: date} do
        calendar = unquote(calendar)
        written = calendar.date_to_string(date.year, date.month, date.day)

        assert calendar.parse_date(written) == {:ok, {date.year, date.month, date.day}}

        for text <- ["abcd-ef-gh", "2026-0a-01", "-abcd-01-01", "2026-W2a-1", "abcd-Wxx-y", ""] do
          assert {:error, reason} = calendar.parse_date(text)
          assert is_atom(reason)
        end

        for text <- [written, "2026-0a-01", "2026-W2a-1"],
            time <- ["10:00:00Z", "1x:00:00", "garbage", "10:00:00.", "10:00:00+0a:00"],
            callback <- [:parse_naive_datetime, :parse_utc_datetime] do
          case apply(calendar, callback, [text <> "T" <> time]) do
            {:ok, _fields} -> assert text == written and callback == :parse_naive_datetime
            {:ok, _fields, _offset} -> assert text == written and time == "10:00:00Z"
            {:error, reason} -> assert is_atom(reason)
          end
        end
      end

      test "the day of the week agrees with ISO for any first day", %{date: date} do
        iso = Date.convert!(date, Calendar.ISO)

        for starting_on <- [:monday, :sunday] do
          assert Date.day_of_week(date, starting_on) == Date.day_of_week(iso, starting_on)
        end
      end

      test "shifting by weeks and adding quarters land on valid dates", %{date: date} do
        calendar = unquote(calendar)

        assert Date.to_gregorian_days(Date.shift(date, week: 1)) ==
                 Date.to_gregorian_days(date) + 7

        {year, month, day} =
          calendar.plus(date.year, date.month, date.day, :quarters, 1, coerce: true)

        assert calendar.valid_date?(year, month, day)
      end

      # A sighting calendar's every date costs a crescent search, so it counts
      # back a single period; its arithmetic is the tabular calendars'.
      test "diff/3 counts back what plus/6 adds", %{date: date} do
        calendar = unquote(calendar)
        from = {date.year, date.month, date.day}
        counts = if calendar in @sighting_calendars, do: [0, 1], else: [0, 1, 13]

        for date_part <- [:years, :quarters, :months, :weeks, :days], count <- counts do
          to = calendar.plus(date.year, date.month, date.day, date_part, count, coerce: true)

          assert calendar.diff(from, to, date_part) == count
          assert calendar.diff(to, from, date_part) == -count
        end
      end

      test "the days of the week are localized in week order", %{date: date} do
        days = Calendrical.localize(date, :days_of_week, locale: :en)
        assert length(days) == 7
        assert days |> Enum.map(&elem(&1, 0)) |> Enum.sort() == Enum.to_list(1..7)
      end

      test "the year, quarter, month and week of the date hold it", %{date: date} do
        iso_days = Date.to_gregorian_days(date)

        for interval <- [
              &Calendrical.Interval.year/1,
              &Calendrical.Interval.quarter/1,
              &Calendrical.Interval.month/1
            ] do
          case interval.(date) do
            %Date.Range{first_in_iso_days: first, last_in_iso_days: last} ->
              assert first <= iso_days and iso_days <= last

            {:error, _not_defined} ->
              :ok
          end
        end

        assert %Date.Range{first_in_iso_days: first, last_in_iso_days: last} =
                 Calendrical.Interval.week(date)

        assert first <= iso_days and iso_days <= last
      end

      # Each day of the sighting-based calendars costs a crescent search, so
      # walking their year takes minutes; they number weeks as the tabular
      # Islamic calendars do.
      unless calendar in @sighting_calendars do
        test "every day of the year is in the week it numbers, and the weeks follow on",
             %{date: date} do
          calendar = unquote(calendar)

          for day <- Calendrical.Interval.year(date) do
            {week_year, week} = Calendrical.week_of_year(day)
            iso_days = Date.to_gregorian_days(day)

            assert %Date.Range{first_in_iso_days: first, last_in_iso_days: last} =
                     Calendrical.Interval.week(week_year, week, calendar)

            assert first <= iso_days and iso_days <= last
          end

          {weeks, _days_in_last_week} = calendar.weeks_in_year(date.year)

          1..weeks
          |> Enum.map(&Calendrical.Interval.week(date.year, &1, calendar))
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.each(fn [earlier, later] ->
            assert earlier.last_in_iso_days + 1 == later.first_in_iso_days
          end)

          assert {:error, :invalid_date} = calendar.week(date.year, weeks + 1)
        end
      end

      test "a date and time moves on by a day and by a month", %{date: date} do
        calendar = unquote(calendar)

        {:ok, naive} =
          NaiveDateTime.new(date.year, date.month, date.day, 10, 30, 0, {0, 0}, calendar)

        next_day = NaiveDateTime.shift(naive, day: 1)

        assert Date.to_gregorian_days(NaiveDateTime.to_date(next_day)) ==
                 Date.to_gregorian_days(date) + 1

        assert next_day.hour == 10

        next_month = NaiveDateTime.shift(naive, month: 1)
        assert calendar.valid_date?(next_month.year, next_month.month, next_month.day)
        assert NaiveDateTime.to_date(next_month) == Date.shift(date, month: 1)
      end

      test "the month is localized and the year formatted", %{date: date} do
        calendar = unquote(calendar)
        assert is_binary(Calendrical.localize(date, :month, locale: :en))

        # Each day of the sighting-based calendars costs a crescent search,
        # so their year takes minutes to lay out; the laying out is shared.
        unless calendar in @sighting_calendars do
          assert is_binary(Calendrical.Format.year(date.year, calendar: calendar))
        end
      end
    end
  end
end
