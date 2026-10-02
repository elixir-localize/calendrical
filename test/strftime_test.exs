defmodule Calendrical.StrftimeTest do
  @moduledoc """
  `Calendrical.strftime/3` names a date's month and day of the week from the
  date, not from its fields. The hand-derived cases are calendars whose fields
  are not the CLDR month and the ISO day: a Hebrew year's Adar, a Chinese leap
  month and thirteenth month, a fiscal year, calendars of weeks, and weeks that
  begin on Sunday. Every day of 2019 to 2021 in each calendar is then compared
  with `Localize.Calendar.localize/3`.

  """

  use ExUnit.Case, async: true

  defp strftime(date, format), do: Calendrical.strftime(date, format, locale: :en)

  defp convert(gregorian, calendar) do
    {:ok, date} = Date.convert(gregorian, calendar)
    date
  end

  test "a Hebrew month is named by its year" do
    assert strftime(Date.new!(5779, 6, 1, Calendrical.Hebrew), "%B") == "Adar I"
    assert strftime(Date.new!(5779, 7, 1, Calendrical.Hebrew), "%B") == "Adar II"
    assert strftime(Date.new!(5779, 8, 1, Calendrical.Hebrew), "%B") == "Nisan"
    assert strftime(Date.new!(5780, 6, 1, Calendrical.Hebrew), "%B") == "Adar"
    assert strftime(Date.new!(5780, 7, 1, Calendrical.Hebrew), "%B") == "Nisan"
  end

  test "a Chinese leap month and a leap year's thirteenth month" do
    # The leap fourth month of 2020 began on 23 May, the twelfth month on
    # 13 January 2021.
    assert strftime(convert(~D[2020-05-23], Calendrical.Chinese), "%B") == "Fourth Monthbis"
    assert strftime(convert(~D[2020-06-21], Calendrical.Chinese), "%B") == "Fifth Month"
    assert strftime(convert(~D[2021-01-13], Calendrical.Chinese), "%B") == "Twelfth Month"
  end

  test "a fiscal calendar's month is named by the month of the year it is" do
    {:ok, fiscal_year_us} = Calendrical.FiscalYear.calendar_for(:US)

    assert strftime(convert(~D[2019-01-01], fiscal_year_us), "%B %b") == "January Jan"
    assert strftime(convert(~D[2018-10-01], fiscal_year_us), "%B %b") == "October Oct"
  end

  test "a calendar of weeks names the month its week falls in" do
    assert strftime(convert(~D[2019-04-01], Calendrical.ISOWeek), "%B") == "M04"
    assert strftime(convert(~D[2020-12-28], Calendrical.ISOWeek), "%B %b") == "M12 M12"
    assert strftime(convert(~D[2019-02-03], Calendrical.NRF), "%B") == "M01"
  end

  test "the day is named by the day it is, whichever day the weeks begin on" do
    # 1 January 2019 was a Tuesday, 26 January 2025 a Sunday.
    for calendar <- [
          Calendrical.Hebrew,
          Calendrical.Ethiopic,
          Calendrical.Islamic.Civil,
          Calendrical.NRF
        ] do
      assert strftime(convert(~D[2019-01-01], calendar), "%A %a") == "Tuesday Tue"
    end

    assert strftime(~D[2025-01-26 Calendrical.IL], "%A %a") == "Sunday Sun"
  end

  test "a value without a date is formatted" do
    assert strftime(~T[14:30:00], "%H:%M %p") == "14:30 PM"
  end

  {:ok, fiscal_year_us} = Calendrical.FiscalYear.calendar_for(:US)

  @calendars [
    Calendrical.Gregorian,
    Calendrical.IL,
    Calendrical.Julian,
    Calendrical.Coptic,
    Calendrical.Ethiopic,
    Calendrical.Hebrew,
    Calendrical.Islamic.Civil,
    Calendrical.Islamic.UmmAlQura,
    Calendrical.Japanese,
    Calendrical.Reform.England,
    Calendrical.Fiscal.US,
    Calendrical.Fiscal.AU,
    fiscal_year_us,
    Calendrical.ISOWeek,
    Calendrical.NRF
  ]

  for calendar <- @calendars do
    test "#{inspect(calendar)} names every month and day as Localize does" do
      calendar = unquote(calendar)

      wrong =
        for gregorian <- Date.range(~D[2019-01-01], ~D[2021-12-31]),
            date = convert(gregorian, calendar),
            expected = expected(date),
            strftime(date, "%B|%b|%A|%a") != expected do
          {date, strftime(date, "%B|%b|%A|%a"), expected}
        end

      assert wrong == [], "#{length(wrong)} days wrong, first: #{inspect(Enum.take(wrong, 3))}"
    end
  end

  defp expected(date) do
    [{:month, :wide}, {:month, :abbreviated}, {:day_of_week, :wide}, {:day_of_week, :abbreviated}]
    |> Enum.map_join("|", fn {part, style} ->
      {:ok, name} = Localize.Calendar.localize(date, part, locale: :en, style: style)
      name
    end)
  end
end
