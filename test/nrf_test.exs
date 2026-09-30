defmodule Calendrical.NRF.Test do
  use ExUnit.Case, async: true

  test "correct NRF start and end dates for several years" do
    nrf_years = %{
      2016 => [{2016, 1, 31}, {2017, 1, 28}],
      2017 => [{2017, 1, 29}, {2018, 2, 3}],
      2018 => [{2018, 2, 4}, {2019, 2, 2}],
      2019 => [{2019, 2, 3}, {2020, 2, 1}],
      2020 => [{2020, 2, 2}, {2021, 1, 30}],
      2021 => [{2021, 1, 31}, {2022, 1, 29}],
      2022 => [{2022, 1, 30}, {2023, 1, 28}],
      2023 => [{2023, 1, 29}, {2024, 2, 3}]
    }

    for {year, [starts, ends]} <- nrf_years do
      assert Calendar.ISO.date_from_iso_days(Calendrical.NRF.first_gregorian_day_of_year(year)) ==
               starts

      assert Calendar.ISO.date_from_iso_days(Calendrical.NRF.last_gregorian_day_of_year(year)) ==
               ends
    end
  end

  test "NRF leap years" do
    assert Calendrical.NRF.leap_year?(2017) == true
    assert Calendrical.NRF.leap_year?(2023) == true
    assert Calendrical.NRF.leap_year?(2022) == false
  end

  # Months of four, five and four weeks: week 9's seventh day is the 35th of
  # the second month. Three months on, or back, is the 35th of the next
  # five-week month, the four-week months between not taking the day with
  # them; one month on is the 28th, the last day of a four-week month.
  test "a shift by months places the day of the month once" do
    config = Calendrical.NRF.__config__()

    assert Calendrical.Base.Week.day_of_month(2024, 9, 7, config) == 35
    assert Calendrical.NRF.plus(2024, 9, 7, :months, 3, coerce: true) == {2024, 22, 7}
    assert Calendrical.NRF.plus(2024, 9, 7, :months, -3, coerce: true) == {2023, 48, 7}
    assert Calendrical.NRF.plus(2024, 9, 7, :months, 1, coerce: true) == {2024, 13, 7}
    assert Calendrical.Base.Week.day_of_month(2024, 22, 7, config) == 35
    assert Calendrical.Base.Week.day_of_month(2023, 48, 7, config) == 35
    assert Calendrical.Base.Week.day_of_month(2024, 13, 7, config) == 28

    assert Date.shift(%Date{year: 2024, month: 9, day: 7, calendar: Calendrical.NRF}, month: 3) ==
             %Date{year: 2024, month: 22, day: 7, calendar: Calendrical.NRF}
  end
end
