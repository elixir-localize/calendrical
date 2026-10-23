defmodule Calendrical.CalendarIntervalTest do
  # CalendarInterval steps an interval of a year or a month through the
  # calendar's own add/9, so these tests guard that integration.
  use ExUnit.Case, async: true

  @calendars [
    Calendrical.Gregorian,
    Calendrical.Julian,
    Calendrical.Hebrew,
    Calendrical.Persian,
    Calendrical.Chinese,
    Calendrical.NRF,
    Calendrical.Reform.England
  ]

  defp interval(calendar, precision) do
    {:ok, date} = Date.convert(~D[2024-01-31], calendar)

    date.year
    |> NaiveDateTime.new!(date.month, date.day, 0, 0, 0, 0, calendar)
    |> CalendarInterval.new(precision)
  end

  test "a Gregorian month interval steps to the next and previous month" do
    month = interval(Calendrical.Gregorian, :month)
    next = CalendarInterval.next(month)

    assert next.first == NaiveDateTime.new!(2024, 2, 1, 0, 0, 0, 0, Calendrical.Gregorian)
    assert NaiveDateTime.to_date(next.last) == Date.new!(2024, 2, 29, Calendrical.Gregorian)

    assert CalendarInterval.prev(month).first ==
             NaiveDateTime.new!(2023, 12, 1, 0, 0, 0, 0, Calendrical.Gregorian)
  end

  for calendar <- @calendars, precision <- [:month, :year] do
    test "#{inspect(calendar)} #{precision} intervals tile: the next begins the day after the last ends" do
      interval = interval(unquote(calendar), unquote(precision))
      next = CalendarInterval.next(interval)

      assert NaiveDateTime.diff(next.first, interval.last, :microsecond) == 1
      assert CalendarInterval.prev(next) == interval
    end
  end

  test "add/9 keeps the time of day and clamps the day into a shorter month" do
    assert Calendrical.Gregorian.add(2024, 1, 31, 9, 15, 30, {5, 1}, :month, 1) ==
             {2024, 2, 29, 9, 15, 30, {5, 1}}

    assert Calendrical.Gregorian.add(2024, 2, 29, 0, 0, 0, {0, 0}, :year, 1) ==
             {2025, 2, 28, 0, 0, 0, {0, 0}}

    assert Calendrical.Gregorian.add(2024, 1, 31, 0, 0, 0, {0, 0}, :quarter, -1) ==
             {2023, 10, 31, 0, 0, 0, {0, 0}}
  end
end
