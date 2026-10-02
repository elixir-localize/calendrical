defmodule Calendrical.YearDaysTest do
  @moduledoc """
  The first and last days of a year, `first_day_of_year/2`,
  `last_day_of_year/2`, `first_gregorian_day_of_year/2`,
  `last_gregorian_day_of_year/2` and `date_from_day_of_year/3`, in every kind
  of calendar: a year need not begin on the first day of a first month.

  The expected days are the calendars' new-year days as they are commonly
  published, given here as Gregorian dates, and none comes from the
  library: Rosh Hashanah 5786 and 5787 (23 September 2025 and 12 September
  2026), the Chinese New Year of 2026 and 2027 (17 February and 6
  February), 1 Muharram 1447 and 1448 in the Umm al-Qura calendar (26 June
  2025 and 16 June 2026), Nowruz 1405 and 1406 (21 March 2026 and 2027),
  the Coptic and Ethiopian new year (11 September 2025 and 2026), 1 Chaitra
  of the Indian national calendar (22 March 2026 and 2027), the United
  States' fiscal year 2026 (1 October 2025 to 30 September 2026), and the
  Julian calendar's distance from the Gregorian, 13 days in 2026, 11 in the
  eighteenth century and 7 from March 1100.

  """

  use ExUnit.Case, async: true

  # {calendar, year, first day, last day}, the days as Gregorian dates.
  @published [
    {Calendar.ISO, 2019, ~D[2019-01-01], ~D[2019-12-31]},
    {Calendrical.Gregorian, 2019, ~D[2019-01-01], ~D[2019-12-31]},
    {Calendrical.NRF, 2019, ~D[2019-02-03], ~D[2020-02-01]},
    {Calendrical.Julian, 2026, ~D[2026-01-14], ~D[2027-01-13]},
    {Calendrical.Julian.March25, 1700, ~D[1700-04-05], ~D[1701-04-04]},
    {Calendrical.Julian.Dec25, 1100, ~D[1099-12-31], ~D[1100-12-31]},
    {Calendrical.Reform.England, 1751, ~D[1751-04-05], ~D[1752-01-11]},
    {Calendrical.Hebrew, 5786, ~D[2025-09-23], ~D[2026-09-11]},
    {Calendrical.Chinese, 4663, ~D[2026-02-17], ~D[2027-02-05]},
    {Calendrical.Islamic.UmmAlQura, 1447, ~D[2025-06-26], ~D[2026-06-15]},
    {Calendrical.Persian, 1405, ~D[2026-03-21], ~D[2027-03-20]},
    {Calendrical.Coptic, 1742, ~D[2025-09-11], ~D[2026-09-10]},
    {Calendrical.Ethiopic, 2018, ~D[2025-09-11], ~D[2026-09-10]},
    {Calendrical.Indian, 1948, ~D[2026-03-22], ~D[2027-03-21]},
    {Calendrical.Japanese, 2026, ~D[2026-01-01], ~D[2026-12-31]},
    {Calendrical.Buddhist, 2569, ~D[2026-01-01], ~D[2026-12-31]},
    {Calendrical.Roc, 115, ~D[2026-01-01], ~D[2026-12-31]}
  ]

  @calendars [
    Calendar.ISO,
    Calendrical.Gregorian,
    Calendrical.ISO,
    Calendrical.ISOWeek,
    Calendrical.NRF,
    Calendrical.Julian,
    Calendrical.Julian.Jan1,
    Calendrical.Julian.March1,
    Calendrical.Julian.March25,
    Calendrical.Julian.Sept1,
    Calendrical.Julian.Dec25,
    Calendrical.Hebrew,
    Calendrical.Coptic,
    Calendrical.Ethiopic,
    Calendrical.Ethiopic.AmeteAlem,
    Calendrical.Persian,
    Calendrical.Islamic.Civil,
    Calendrical.Islamic.Tbla,
    Calendrical.Islamic.UmmAlQura,
    Calendrical.Chinese,
    Calendrical.Korean,
    Calendrical.Vietnamese,
    Calendrical.LunarJapanese,
    Calendrical.Japanese,
    Calendrical.Buddhist,
    Calendrical.Roc,
    Calendrical.Indian,
    Calendrical.Reform.England,
    Calendrical.Reform.Sweden,
    Calendrical.Reform.Japan
  ]

  defp gregorian(date), do: Date.convert!(date, Calendrical.Gregorian)

  defp calendars do
    {:ok, fiscal} = Calendrical.FiscalYear.calendar_for(:US)
    {:ok, territory} = Calendrical.calendar_from_territory(:GB)
    {:ok, reform} = Calendrical.Reform.calendar_for(:DE)

    @calendars ++ [fiscal, territory, reform]
  end

  describe "the first and last days of a year, as they are published" do
    test "first_gregorian_day_of_year/2 and last_gregorian_day_of_year/2" do
      for {calendar, year, first, last} <- @published do
        assert Calendrical.first_gregorian_day_of_year(year, calendar) == gregorian(first),
               "#{inspect(calendar)} #{year}"

        assert Calendrical.last_gregorian_day_of_year(year, calendar) == gregorian(last),
               "#{inspect(calendar)} #{year}"
      end
    end

    test "first_day_of_year/2 and last_day_of_year/2 are those days in the calendar" do
      for {calendar, year, first, last} <- @published do
        assert Calendrical.first_day_of_year(year, calendar) == Date.convert!(first, calendar),
               "#{inspect(calendar)} #{year}"

        assert Calendrical.last_day_of_year(year, calendar) == Date.convert!(last, calendar),
               "#{inspect(calendar)} #{year}"
      end
    end

    test "the United States' fiscal year 2026" do
      {:ok, fiscal} = Calendrical.FiscalYear.calendar_for(:US)

      assert Calendrical.first_gregorian_day_of_year(2026, fiscal) == gregorian(~D[2025-10-01])
      assert Calendrical.last_gregorian_day_of_year(2026, fiscal) == gregorian(~D[2026-09-30])
      assert Calendrical.last_day_of_year(2026, fiscal) == Date.convert!(~D[2026-09-30], fiscal)
    end

    test "a year reckoned from another day than 1 January begins on that day" do
      assert Calendrical.first_day_of_year(1700, Calendrical.Julian.March25) ==
               ~D[1700-03-25 Calendrical.Julian.March25]

      assert Calendrical.last_day_of_year(1700, Calendrical.Julian.March25) ==
               ~D[1700-03-24 Calendrical.Julian.March25]

      assert Calendrical.first_day_of_year(1100, Calendrical.Julian.Dec25) ==
               ~D[1100-12-25 Calendrical.Julian.Dec25]

      assert Calendrical.first_day_of_year(1751, Calendrical.Reform.England) ==
               ~D[1751-03-25 Calendrical.Reform.England]

      assert Calendrical.last_day_of_year(1751, Calendrical.Reform.England) ==
               ~D[1751-12-31 Calendrical.Reform.England]
    end
  end

  # What holds of any year: its first and last days carry its number, lie
  # as many days apart as the year has days, and the day after the last is
  # the first day of the year after.
  describe "the first and last days of a year in every kind of calendar" do
    test "bound the year's days" do
      for calendar <- calendars(), offset <- [-1, 0, 1] do
        year = Date.convert!(~D[2026-06-15], calendar).year + offset
        first = Calendrical.first_day_of_year(year, calendar)
        last = Calendrical.last_day_of_year(year, calendar)
        days_in_year = Date.diff(last, first) + 1
        context = "#{inspect(calendar)} #{year}"

        assert %Date{year: ^year, calendar: ^calendar} = first, context
        assert %Date{year: ^year, calendar: ^calendar} = last, context
        assert days_in_year > 0, context

        assert Date.add(last, 1) ==
                 Calendrical.first_day_of_year(Date.add(last, 1).year, calendar),
               context

        assert Date.add(last, 1).year != year, context
        assert Date.add(first, -1).year != year, context

        assert Calendrical.first_gregorian_day_of_year(year, calendar) == gregorian(first),
               context

        assert Calendrical.last_gregorian_day_of_year(year, calendar) == gregorian(last), context
        assert Calendrical.date_from_day_of_year(year, 1, calendar) == first, context
        assert Calendrical.date_from_day_of_year(year, days_in_year, calendar) == last, context

        assert Calendrical.date_from_day_of_year(year, days_in_year + 1, calendar) ==
                 {:error, :invalid_date},
               context

        if calendar != Calendar.ISO do
          assert calendar.days_in_year(year) == days_in_year, context
        end
      end
    end

    test "a date's year has the same first and last days" do
      for calendar <- calendars() do
        date = Date.convert!(~D[2026-06-15], calendar)

        assert Calendrical.first_day_of_year(date) ==
                 Calendrical.first_day_of_year(date.year, calendar)

        assert Calendrical.last_day_of_year(date) ==
                 Calendrical.last_day_of_year(date.year, calendar)

        assert gregorian(Calendrical.first_gregorian_day_of_year(date)) ==
                 Calendrical.first_gregorian_day_of_year(date.year, calendar)

        assert gregorian(Calendrical.last_gregorian_day_of_year(date)) ==
                 Calendrical.last_gregorian_day_of_year(date.year, calendar)
      end
    end

    test "a date of Calendar.ISO keeps its calendar" do
      assert Calendrical.first_day_of_year(~D[2019-12-01]) == ~D[2019-01-01]
      assert Calendrical.last_day_of_year(~D[2019-12-01]) == ~D[2019-12-31]
      assert Calendrical.first_gregorian_day_of_year(~D[2019-12-01]) == ~D[2019-01-01]
      assert Calendrical.last_gregorian_day_of_year(~D[2019-12-01]) == ~D[2019-12-31]
      assert Calendrical.date_from_day_of_year(2019, 32, Calendar.ISO) == ~D[2019-02-01]
    end
  end

  describe "a year a calendar does not have" do
    test "is an error, never a raise" do
      for {year, calendar} <- [
            {0, Calendrical.Julian},
            {0, Calendrical.Julian.March25},
            {1500, Calendrical.Reform.Japan},
            {nil, Calendrical.Gregorian},
            {"2019", Calendrical.Hebrew}
          ] do
        context = "#{inspect(calendar)} #{inspect(year)}"

        assert Calendrical.first_day_of_year(year, calendar) == {:error, :invalid_date}, context
        assert Calendrical.last_day_of_year(year, calendar) == {:error, :invalid_date}, context

        assert Calendrical.first_gregorian_day_of_year(year, calendar) ==
                 {:error, :invalid_date},
               context

        assert Calendrical.last_gregorian_day_of_year(year, calendar) == {:error, :invalid_date},
               context

        assert Calendrical.date_from_day_of_year(year, 1, calendar) == {:error, :invalid_date},
               context
      end
    end

    test "a day of the year below 1 or beyond the year is an error" do
      assert Calendrical.date_from_day_of_year(2019, 0) == {:error, :invalid_date}
      assert Calendrical.date_from_day_of_year(2019, 366) == {:error, :invalid_date}
      assert Calendrical.date_from_day_of_year(2020, 366) == ~D[2020-12-31 Calendrical.Gregorian]
      assert Calendrical.date_from_day_of_year(2019, 1.5) == {:error, :invalid_date}
    end
  end
end
