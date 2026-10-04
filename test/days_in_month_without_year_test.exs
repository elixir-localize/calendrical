defmodule Calendrical.DaysInMonthWithoutYearTest do
  @moduledoc """
  `days_in_month/1` answers for a month with no year: the number of days
  where the month has as many in every year, `{:ambiguous, range}` where
  its length depends on the year, and `{:error, :undefined}` for a month
  the calendar does not have. Every calendar built on
  `Calendrical.Behaviour` answered `{:error, :undefined}` for every month.

  The oracle is the calendar's own `days_in_month/2` over a span of years:
  the lengths a month takes there are the answer.

  """

  use ExUnit.Case, async: true

  # A span of years for each calendar. The calendars that find their months
  # by astronomy take a short one.
  @calendars [
    {Calendrical.Gregorian, 1900..2200},
    {Calendrical.Buddhist, 2400..2700},
    {Calendrical.Roc, 1..300},
    {Calendrical.Japanese, 1900..2200},
    {Calendrical.Indian, 1800..2100},
    {Calendrical.Persian, 1300..1600},
    {Calendrical.Coptic, 1600..1900},
    {Calendrical.Ethiopic, 1900..2200},
    {Calendrical.Ethiopic.AmeteAlem, 7400..7700},
    {Calendrical.Hebrew, 5600..5900},
    {Calendrical.Islamic.Civil, 1300..1600},
    {Calendrical.Islamic.Tbla, 1300..1600},
    {Calendrical.Islamic.UmmAlQura, 1300..1600},
    {Calendrical.Islamic.Observational, 1440..1450},
    {Calendrical.Islamic.Rgsa, 1440..1450},
    {Calendrical.Reform.Sweden.Transitional, 1690..1720}
  ]

  for {calendar, years} <- @calendars do
    test "#{inspect(calendar)} answers each month's lengths over #{inspect(years)}" do
      calendar = unquote(calendar)

      for month <- 1..14 do
        lengths =
          for year <- unquote(Macro.escape(years)),
              month <= calendar.months_in_year(year),
              uniq: true,
              do: calendar.days_in_month(year, month)

        expected =
          case Enum.sort(lengths) do
            [] -> {:error, :undefined}
            [days] -> days
            several -> {:ambiguous, List.first(several)..List.last(several)}
          end

        assert calendar.days_in_month(month) == expected, "month #{month}"
      end
    end
  end

  test "the months Tempo found" do
    assert Calendrical.Coptic.days_in_month(1) == 30
    assert Calendrical.Coptic.days_in_month(13) == {:ambiguous, 5..6}
    assert Calendrical.Persian.days_in_month(12) == {:ambiguous, 29..30}
    assert Calendrical.Indian.days_in_month(1) == {:ambiguous, 30..31}
    assert Calendrical.Islamic.Civil.days_in_month(12) == {:ambiguous, 29..30}
    assert Calendrical.Islamic.UmmAlQura.days_in_month(9) == {:ambiguous, 29..30}
    assert Calendrical.Hebrew.days_in_month(13) == 29
    assert Calendrical.Buddhist.days_in_month(2) == Calendrical.Gregorian.days_in_month(2)
    assert Calendrical.Reform.Sweden.Transitional.days_in_month(2) == {:ambiguous, 28..30}
  end

  test "a month the calendar does not have is undefined" do
    for {calendar, _years} <- @calendars,
        calendar != Calendrical.Gregorian,
        month <- [0, -1, 14, 100, nil, "1", 1.0, :january] do
      assert calendar.days_in_month(month) == {:error, :undefined},
             "#{inspect(calendar)} #{inspect(month)}"
    end
  end
end
