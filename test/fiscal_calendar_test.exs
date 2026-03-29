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
end
