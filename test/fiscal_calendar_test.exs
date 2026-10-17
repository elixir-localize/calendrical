defmodule Calendrical.FiscalCalendar.Test do
  use ExUnit.Case, async: true

  test "creation of a fiscal calendar" do
    assert {_, Calendrical.FiscalYear.US} = Calendrical.FiscalYear.calendar_for(:US)

    assert {:error, _} = Calendrical.FiscalYear.calendar_for(:XT)
  end

  test "US Fiscal dates" do
    {_, us} = Calendrical.FiscalYear.calendar_for(:US)
    year = us.year(2021)

    assert Date.convert!(year.first, Calendrical.Gregorian) ==
             ~D[2020-10-01 Calendrical.Gregorian]

    assert Date.convert!(year.last, Calendrical.Gregorian) ==
             ~D[2021-09-30 Calendrical.Gregorian]
  end

  test "AU Fiscal dates" do
    {:ok, au} = Calendrical.FiscalYear.calendar_for(:AU)
    year = au.year(2022)

    assert Date.convert!(year.first, Calendrical.Gregorian) ==
             ~D[2021-07-01 Calendrical.Gregorian]

    assert Date.convert!(year.last, Calendrical.Gregorian) ==
             ~D[2022-06-30 Calendrical.Gregorian]
  end

  # A fiscal year's ranges are its own: year 2027 of a fiscal year that
  # begins in July runs from July 2026, its month 1 is July and its
  # quarter 1 July to September, whatever year its dates are written with.
  describe "the ranges of a fiscal year" do
    test "are the fiscal year's, month's and quarter's days" do
      for {territory, ranges} <- [
            {:AU,
             [
               year: {~D[2026-07-01], ~D[2027-06-30]},
               month_1: {~D[2026-07-01], ~D[2026-07-31]},
               month_12: {~D[2027-06-01], ~D[2027-06-30]},
               quarter_1: {~D[2026-07-01], ~D[2026-09-30]},
               quarter_4: {~D[2027-04-01], ~D[2027-06-30]}
             ]},
            {:US,
             [
               year: {~D[2026-10-01], ~D[2027-09-30]},
               month_1: {~D[2026-10-01], ~D[2026-10-31]},
               month_12: {~D[2027-09-01], ~D[2027-09-30]},
               quarter_1: {~D[2026-10-01], ~D[2026-12-31]},
               quarter_4: {~D[2027-07-01], ~D[2027-09-30]}
             ]},
            {:GB,
             [
               year: {~D[2027-04-01], ~D[2028-03-31]},
               month_1: {~D[2027-04-01], ~D[2027-04-30]},
               month_12: {~D[2028-03-01], ~D[2028-03-31]},
               quarter_1: {~D[2027-04-01], ~D[2027-06-30]},
               quarter_4: {~D[2028-01-01], ~D[2028-03-31]}
             ]}
          ] do
        {:ok, calendar} = Calendrical.FiscalYear.calendar_for(territory)

        for {range, expected} <- [
              {calendar.year(2027), ranges[:year]},
              {calendar.month(2027, 1), ranges[:month_1]},
              {calendar.month(2027, 12), ranges[:month_12]},
              {calendar.quarter(2027, 1), ranges[:quarter_1]},
              {calendar.quarter(2027, 4), ranges[:quarter_4]}
            ] do
          assert {Date.convert!(range.first, Calendar.ISO),
                  Date.convert!(range.last, Calendar.ISO)} ==
                   expected,
                 inspect(territory)
        end
      end
    end
  end

  # A fiscal calendar's months are named as the Gregorian months they are,
  # so its dates are written as the Gregorian dates they are (user,
  # 2026-10-16): year 2027 of the fiscal year from July holds 10 August
  # 2026, which is written with 2026, where it was written "Aug 10, 2027".
  describe "a fiscal date is written as the Gregorian date it is" do
    setup do
      {:ok, au} = Calendrical.FiscalYear.calendar_for(:AU)
      %{au: au, august: Date.new!(2027, 2, 10, au), february: Date.new!(2027, 8, 10, au)}
    end

    test "in every format", %{august: august, february: february} do
      assert Localize.Date.to_string(august, format: :long, locale: :en) ==
               {:ok, "August 10, 2026"}

      assert Localize.Date.to_string(august, format: :short, locale: :en) == {:ok, "8/10/26"}

      assert Localize.Date.to_string(august, format: "y-MM-dd", locale: :en) ==
               {:ok, "2026-08-10"}

      assert Localize.Date.to_string(february, format: :long, locale: :en) ==
               {:ok, "February 10, 2027"}

      assert Calendrical.strftime(august, "%d/%m/%Y %B", locale: :en) ==
               {:ok, "10/08/2026 August"}
    end

    test "and is read back as the fiscal date", %{au: au} do
      for territory <- [:AU, :US, :GB, :JP],
          {:ok, calendar} = Calendrical.FiscalYear.calendar_for(territory),
          iso <- Date.range(~D[2026-01-01], ~D[2027-12-31]),
          format <- [:long, :short] do
        date = Date.convert!(iso, calendar)
        {:ok, text} = Localize.Date.to_string(date, format: format, locale: :en)

        assert Localize.Date.parse(text, calendar: calendar, format: format, locale: :en) ==
                 {:ok, date},
               "#{inspect(territory)} #{text}"
      end

      assert Localize.Date.parse("August 10, 2026", calendar: au, format: :long, locale: :en) ==
               {:ok, Date.new!(2027, 2, 10, au)}
    end

    test "with both years in an interval across 1 January", %{au: au, august: august} do
      assert {:ok, text} =
               Localize.Interval.to_string(august, Date.new!(2027, 8, 15, au),
                 format: :medium,
                 locale: :en
               )

      assert text =~ "Aug 10, 2026"
      assert text =~ "Feb 15, 2027"
    end

    test "while its year stays the fiscal year", %{au: au, august: august} do
      assert august.year == 2027
      assert au.cardinal_year(2027, 2, 10) == 2026
      assert Calendrical.Interval.year(august) == au.year(2027)
    end
  end
end
