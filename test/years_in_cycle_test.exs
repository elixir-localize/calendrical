defmodule Calendrical.YearsInCycleTest do
  @moduledoc """
  The years a calendar comes round in (`years_in_cycle/0`), which every
  calendar answers: a number, or that it has none.

  A consumer that wanted to know whether something holds of every year of
  a calendar held the Gregorian calendar's 400 years itself. Each calendar
  says its own now.

  The measure is the calendar's own years, a year at a time: a year has
  the layout of the year a cycle before it, the days of each of its months
  in order and the weekday of its first day, for every year of two cycles
  and more. The numbers themselves are known apart from the library: the
  Gregorian leap rule repeats in 400 years, which are 146,097 days and
  20,871 weeks; the Julian in 4 years of 1,461 days, which are a whole
  number of weeks after seven of them, 28 years; and the tabular Islamic
  calendar in 30 years of 10,631 days, a whole number of weeks after seven
  of them, 210 years.

  """

  use ExUnit.Case, async: true

  {:ok, modules} = :application.get_key(:calendrical, :modules)

  @calendars for module <- Enum.sort(modules),
                 Code.ensure_loaded?(module),
                 function_exported?(module, :years_in_cycle, 0),
                 function_exported?(module, :date_to_iso_days, 3),
                 do: module

  # A year's layout: the days of each month it has, in order, and the
  # weekday of its first day.
  defp layout(calendar, year) do
    %Date.Range{first: first} = calendar.year(year)

    months =
      for months <- calendar.month_numbers(year), month <- months do
        calendar.day_numbers(year, month)
      end

    {weekday, _first, _last} = calendar.day_of_week(first.year, first.month, first.day, :monday)
    {months, calendar.days_in_year(year), weekday}
  end

  describe "years_in_cycle/0" do
    test "is known for the calendars that count by a rule that comes round" do
      assert Calendrical.Gregorian.years_in_cycle() == 400
      assert Calendrical.ISOWeek.years_in_cycle() == 400
      assert Calendrical.Julian.years_in_cycle() == 28
      assert Calendrical.Julian.March25.years_in_cycle() == 28
      assert Calendrical.Coptic.years_in_cycle() == 28
      assert Calendrical.Ethiopic.years_in_cycle() == 28
      assert Calendrical.Islamic.Civil.years_in_cycle() == 210
      assert Calendrical.Islamic.Tbla.years_in_cycle() == 210
      assert Calendrical.Indian.years_in_cycle() == 400
    end

    test "is undefined for a calendar reckoned from the sky, and for a composite" do
      for calendar <- [
            Calendrical.Hebrew,
            Calendrical.Chinese,
            Calendrical.Persian,
            Calendrical.Islamic.UmmAlQura,
            Calendrical.Islamic.Observational,
            Calendrical.Reform.England
          ] do
        assert calendar.years_in_cycle() == {:error, :undefined}, inspect(calendar)
      end
    end

    test "every calendar that names a cycle has, each year, the layout of the year a cycle before" do
      for calendar <- @calendars,
          cycle = apply(calendar, :years_in_cycle, []),
          is_integer(cycle) do
        first_year = 1000

        for year <- first_year..(first_year + 2 * cycle + 30) do
          assert layout(calendar, year + cycle) == layout(calendar, year),
                 "#{inspect(calendar)} #{year} and #{year + cycle}"
        end
      end
    end

    test "no shorter run of years the cycle divides into is one" do
      for {calendar, cycle} <- [
            {Calendrical.Gregorian, 400},
            {Calendrical.Julian, 28},
            {Calendrical.Islamic.Civil, 210}
          ],
          shorter <- 1..(cycle - 1),
          rem(cycle, shorter) == 0 do
        refute Enum.all?(1000..(1000 + cycle), fn year ->
                 layout(calendar, year + shorter) == layout(calendar, year)
               end),
               "#{inspect(calendar)} comes round in #{shorter}"
      end
    end
  end
end
