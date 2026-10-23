defmodule Calendrical.YearNumberingTest do
  @moduledoc """
  The Gregorian year that numbers a month or week calendar's year, for every
  `:year`, `:first_or_last` and `:month_of_year`, checked against the
  definitions rather than the implementation.

  A year that does not begin in January begins in one Gregorian year, `B`, the
  one holding its first week, and ends in the next, `E`, the one holding its
  last. `:beginning` numbers it `B`, `:ending` numbers it `E`, and `:majority`
  numbers it by the Gregorian year holding seven or more of its months. A month
  calendar's `:month_of_year` is its first month whatever `:first_or_last`
  says, since `:first_or_last` chooses a day of the week, which a month
  calendar has no use for.

  """

  use ExUnit.Case, async: true

  @years 1999..2002
  @month_lengths %{
    1 => 31,
    2 => 28,
    3 => 31,
    4 => 30,
    5 => 31,
    6 => 30,
    7 => 31,
    8 => 31,
    9 => 30,
    10 => 31,
    11 => 30,
    12 => 31
  }

  defp gregorian_year(iso_days), do: iso_days |> Calendar.ISO.date_from_iso_days() |> elem(0)

  # A calendar of weeks anchored by a Monday of a month: begun on the Monday
  # on or before its 4th, or ended on the Monday on or after its fourth-last
  # day, and numbered by `year_number`.
  defp week_calendar(:begins, month, year_number) do
    name = Module.concat([__MODULE__, "Begins#{month}#{year_number}"])

    {:ok, calendar} =
      Calendrical.new(name, :week,
        year_begins: {:monday, :on_or_before, {month, 4}},
        year_number: year_number
      )

    calendar
  end

  defp week_calendar(:ends, month, year_number) do
    name = Module.concat([__MODULE__, "Ends#{month}#{year_number}"])
    day = Map.fetch!(@month_lengths, month) - 3

    {:ok, calendar} =
      Calendrical.new(name, :week,
        year_ends: {:monday, :on_or_after, {month, day}},
        year_number: year_number
      )

    calendar
  end

  # The calendars are built once, here, through the one `Calendrical.Compiler`
  # server, which compiles one calendar at a time: built in the tests, the
  # four tests queue on it and a slow runner outlasts the test timeout.
  setup_all do
    calendars =
      for anchor <- [:begins, :ends],
          year_option <- [:beginning, :ending],
          month <- 1..12,
          into: %{} do
        {{anchor, year_option, month}, week_calendar(anchor, month, year_option)}
      end

    {:ok, calendars: calendars}
  end

  # The Gregorian years holding the first and the last week of `year`.
  defp beginning_and_ending(calendar, year) do
    first = calendar.first_gregorian_day_of_year(year)
    last = calendar.last_gregorian_day_of_year(year)
    {gregorian_year(first + 6), gregorian_year(last - 6)}
  end

  # The Gregorian year that `:year_number` numbers the calendar year by.
  defp named_year(:beginning, beginning, _ending), do: beginning
  defp named_year(:ending, _beginning, ending), do: ending

  for anchor <- [:begins, :ends], year_option <- [:beginning, :ending] do
    test "a calendar of weeks that #{anchor} by its rule, year_number: #{year_option}",
         %{calendars: calendars} do
      year_option = unquote(year_option)

      for month <- 1..12, year <- @years do
        calendar = Map.fetch!(calendars, {unquote(anchor), year_option, month})
        {beginning, ending} = beginning_and_ending(calendar, year)
        named = named_year(year_option, beginning, ending)
        context = "#{inspect(calendar)}, year #{year}"

        assert calendar.last_gregorian_day_of_year(year) + 1 ==
                 calendar.first_gregorian_day_of_year(year + 1),
               "year does not end the day before the next begins: #{context}"

        assert named == year, "named #{named}, not #{year}: #{context}"
        assert calendar.year_of_era(year) == {year, 1}, "year_of_era: #{context}"
      end
    end
  end

  # A month calendar begun in month `m` is a `Calendrical.Calendar.Shifted`
  # calendar; its year is numbered by the Gregorian year it begins in, ends
  # in, or holds seven or more of its months. A tie, six and six, follows the
  # existing convention and is not asserted here. The body is a function of
  # the rule, so that the type checker holds it to every rule and not to the
  # one each test names.
  test "a month calendar with year_number: beginning", do: assert_year_number(:beginning)
  test "a month calendar with year_number: ending", do: assert_year_number(:ending)
  test "a month calendar with year_number: majority", do: assert_year_number(:majority)

  defp assert_year_number(year_number) do
    for month <- 1..12, {month, year_number} != {7, :majority} do
      name = Module.concat([__MODULE__, "Month#{month}#{year_number}"])

      {:ok, calendar} =
        Calendrical.new(name, :month, year_begins: {month, 1}, year_number: year_number)

      for year <- @years do
        first = Date.to_gregorian_days(calendar.year(year).first)
        last = Date.to_gregorian_days(calendar.year(year).last)
        {beginning, ending} = {gregorian_year(first + 6), gregorian_year(last - 6)}
        named = named_year(year_number, month, beginning, ending)

        context = "year_begins {#{month}, 1}, year #{year}"
        assert last + 1 == Date.to_gregorian_days(calendar.year(year + 1).first), context
        assert named == year, "named #{named}, not #{year}: #{context}"
        assert calendar.year_of_era(year) == {year, 1}, "year_of_era: #{context}"
      end
    end
  end

  defp named_year(:majority, month, beginning, ending),
    do: if(13 - month >= 7, do: beginning, else: ending)

  defp named_year(rule, _month, beginning, ending), do: named_year(rule, beginning, ending)
end
