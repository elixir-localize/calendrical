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

  alias Calendrical.Base.Week
  alias Calendrical.Config

  @years 1999..2002

  defp config(month, first_or_last, year_option) do
    %Config{
      month_of_year: month,
      first_or_last: first_or_last,
      year: year_option,
      day_of_week: 1,
      min_days_in_first_week: 4
    }
  end

  defp gregorian_year(iso_days), do: iso_days |> Calendar.ISO.date_from_iso_days() |> elem(0)

  # The Gregorian years holding the first and the last week of `year`.
  defp beginning_and_ending(kind, year, config) do
    first = kind.first_gregorian_day_of_year(year, config)
    last = kind.last_gregorian_day_of_year(year, config)
    {gregorian_year(first + 6), gregorian_year(last - 6)}
  end

  # The Gregorian year that `:year` numbers the calendar year by.
  defp named_year(:beginning, beginning, _ending), do: beginning
  defp named_year(:ending, _beginning, ending), do: ending

  for kind <- [Week],
      first_or_last <- [:first, :last],
      year_option <- [:beginning, :ending] do
    test "#{inspect(kind)} with first_or_last: #{first_or_last}, year: #{year_option}" do
      kind = unquote(kind)
      year_option = unquote(year_option)

      for month <- 1..12, year <- @years do
        config = config(month, unquote(first_or_last), year_option)
        {beginning, ending} = beginning_and_ending(kind, year, config)
        named = named_year(year_option, beginning, ending)
        context = "month_of_year #{month}, year #{year}"

        assert kind.last_gregorian_day_of_year(year, config) + 1 ==
                 kind.first_gregorian_day_of_year(year + 1, config),
               "year does not end the day before the next begins: #{context}"

        assert named == year, "named #{named}, not #{year}: #{context}"
        assert kind.year_of_era(year, config) == {year, 1}, "year_of_era: #{context}"
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
