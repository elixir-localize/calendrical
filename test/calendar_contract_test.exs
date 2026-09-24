defmodule Calendrical.CalendarContract.Test do
  @moduledoc """
  The calendar contract, checked for every calendar module in the library: a
  date in each calendar answers the `Calendar` and `Calendrical` questions
  without raising, and invalid arguments are errors rather than crashes.

  """

  use ExUnit.Case, async: true

  {:ok, modules} = :application.get_key(:calendrical, :modules)

  @sighting_calendars [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa]

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

      test "a period the year does not have is an error", %{date: date} do
        calendar = unquote(calendar)

        for month <- [0, 99], do: assert({:error, _} = calendar.month(date.year, month))
        for quarter <- [0, 5], do: assert({:error, _} = calendar.quarter(date.year, quarter))
        assert {:error, _} = calendar.week(date.year, 99)
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
              &Calendrical.Interval.month/1,
              &Calendrical.Interval.week/1
            ] do
          case interval.(date) do
            %Date.Range{first_in_iso_days: first, last_in_iso_days: last} ->
              assert first <= iso_days and iso_days <= last

            {:error, _not_defined} ->
              :ok
          end
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
