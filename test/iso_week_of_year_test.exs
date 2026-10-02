defmodule Calendrical.IsoWeekOfYearTest do
  @moduledoc """
  `iso_week_of_year/3` gives the ISO 8601 week of the day a date names,
  whichever calendar names it. Every day of 2018 to 2020 is converted into
  each calendar and its answer compared with Erlang's
  `:calendar.iso_week_number/1` for the same day.

  The calendars that count months by astronomy are left out for speed.

  """

  use ExUnit.Case, async: true

  @first_day ~D[2018-01-01]
  @last_day ~D[2020-12-31]

  {:ok, fiscal_year_us} = Calendrical.FiscalYear.calendar_for(:US)
  {:ok, fiscal_year_au} = Calendrical.FiscalYear.calendar_for(:AU)

  @calendars [
    Calendrical.Gregorian,
    Calendrical.ISO,
    Calendrical.Japanese,
    Calendrical.Buddhist,
    Calendrical.Roc,
    Calendrical.Julian,
    Calendrical.Julian.March25,
    Calendrical.Julian.Sept1,
    Calendrical.Coptic,
    Calendrical.Ethiopic,
    Calendrical.Hebrew,
    Calendrical.Islamic.Civil,
    Calendrical.Islamic.Tbla,
    Calendrical.Islamic.UmmAlQura,
    Calendrical.NRF,
    Calendrical.ISOWeek,
    Calendrical.Reform.England,
    Calendrical.Fiscal.US,
    Calendrical.Fiscal.UK,
    Calendrical.Fiscal.AU,
    fiscal_year_us,
    fiscal_year_au
  ]

  for calendar <- @calendars do
    test "#{inspect(calendar)} gives the ISO week of the day" do
      calendar = unquote(calendar)

      wrong =
        for gregorian <- Date.range(@first_day, @last_day),
            {:ok, date} = Date.convert(gregorian, calendar),
            expected = :calendar.iso_week_number(Date.to_erl(gregorian)),
            calendar.iso_week_of_year(date.year, date.month, date.day) != expected do
          {gregorian, date, calendar.iso_week_of_year(date.year, date.month, date.day), expected}
        end

      assert wrong == [],
             "#{length(wrong)} days wrong, first: #{inspect(Enum.take(wrong, 3))}"
    end
  end
end
