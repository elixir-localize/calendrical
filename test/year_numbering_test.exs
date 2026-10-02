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

  alias Calendrical.Base.{Month, Week}
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

  for kind <- [Month, Week],
      first_or_last <- [:first, :last],
      year_option <- [:beginning, :ending] do
    test "#{inspect(kind)} with first_or_last: #{first_or_last}, year: #{year_option}" do
      kind = unquote(kind)
      year_option = unquote(year_option)

      for month <- 1..12, year <- @years do
        config = config(month, unquote(first_or_last), year_option)
        {beginning, ending} = beginning_and_ending(kind, year, config)
        named = if year_option == :beginning, do: beginning, else: ending
        context = "month_of_year #{month}, year #{year}"

        assert kind.last_gregorian_day_of_year(year, config) + 1 ==
                 kind.first_gregorian_day_of_year(year + 1, config),
               "year does not end the day before the next begins: #{context}"

        assert named == year, "named #{named}, not #{year}: #{context}"
        assert kind.year_of_era(year, config) == {year, 1}, "year_of_era: #{context}"
      end
    end
  end

  for first_or_last <- [:first, :last] do
    test "Calendrical.Base.Month with first_or_last: #{first_or_last}, year: :majority" do
      # A month calendar beginning in month `m` has 13 - m months in its first
      # Gregorian year. A tie, six and six, follows the existing convention and
      # is not asserted here.
      for month <- 1..12, month != 7, year <- @years do
        config = config(month, unquote(first_or_last), :majority)
        {beginning, ending} = beginning_and_ending(Month, year, config)
        named = if 13 - month >= 7, do: beginning, else: ending
        context = "month_of_year #{month}, year #{year}"

        assert Month.last_gregorian_day_of_year(year, config) + 1 ==
                 Month.first_gregorian_day_of_year(year + 1, config),
               "year does not end the day before the next begins: #{context}"

        assert named == year, "named #{named}, not #{year}: #{context}"
        assert Month.year_of_era(year, config) == {year, 1}, "year_of_era: #{context}"
      end
    end
  end
end
