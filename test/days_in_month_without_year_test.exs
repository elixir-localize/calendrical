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
    {Calendrical.Reform.Sweden.Transitional, 1690..1720},
    {Calendrical.Julian, 1900..2200},
    {Calendrical.Julian.Jan1, 1900..2200},
    {Calendrical.Julian.March1, 1900..2200},
    {Calendrical.Julian.March25, 1900..2200},
    {Calendrical.Julian.Sept1, 1900..2200},
    {Calendrical.Julian.Dec25, 1900..2200}
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
    for {calendar, _years} <- @calendars, month <- [0, -1, 14, 100] do
      assert calendar.days_in_month(month) == {:error, :undefined},
             "#{inspect(calendar)} #{inspect(month)}"
    end
  end

  # The callback answers a value that is not a month with `{:error, :undefined}`
  # or `{:error, exception}`: the month calendars name the missing year.
  test "a value that is not a month is an error" do
    for {calendar, _years} <- @calendars, month <- [nil, "1", 1.0, :january] do
      assert {:error, reason} = calendar.days_in_month(month)

      assert reason == :undefined or is_exception(reason),
             "#{inspect(calendar)} #{inspect(month)}"
    end
  end

  describe "months_in_year/0" do
    test "the Julian calendars have twelve months, as the Gregorian has" do
      for calendar <- [
            Calendrical.Julian,
            Calendrical.Julian.Jan1,
            Calendrical.Julian.March1,
            Calendrical.Julian.March25,
            Calendrical.Julian.Sept1,
            Calendrical.Julian.Dec25
          ] do
        assert calendar.months_in_year() == Calendrical.Gregorian.months_in_year()
        assert calendar.months_in_year() == 12
      end
    end

    test "every calendar answers, a composite that it cannot" do
      for {calendar, years} <- @calendars do
        counts = for year <- years, uniq: true, do: calendar.months_in_year(year)

        expected =
          case Enum.sort(counts) do
            [months] -> months
            several -> {:ambiguous, List.first(several)..List.last(several)}
          end

        assert calendar.months_in_year() == expected, inspect(calendar)
      end

      assert Calendrical.Reform.England.months_in_year() == {:error, :undefined}
      assert Calendrical.Reform.England.days_in_month(2) == {:error, :undefined}
    end
  end
end
