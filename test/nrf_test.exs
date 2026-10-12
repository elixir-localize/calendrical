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

  # Months of four, five and four weeks: the 35th of the second month is the
  # last day of a five-week month. Three months on, or back, is the 35th of
  # the next five-week month, the four-week months between not taking the
  # day with them; one month on is the 28th, the last day of a four-week
  # month.
  test "a shift by months places the day of the month once" do
    assert Calendrical.NRF.days_in_month(2024, 2) == 35
    assert Calendrical.NRF.week_date_from_date(2024, 2, 35) == {2024, 9, 7}

    assert Calendrical.NRF.plus(2024, 2, 35, :months, 3, coerce: true) == {2024, 5, 35}
    assert Calendrical.NRF.plus(2024, 2, 35, :months, -3, coerce: true) == {2023, 11, 35}
    assert Calendrical.NRF.plus(2024, 2, 35, :months, 1, coerce: true) == {2024, 3, 28}

    assert Date.shift(%Date{year: 2024, month: 2, day: 35, calendar: Calendrical.NRF}, month: 3) ==
             %Date{year: 2024, month: 5, day: 35, calendar: Calendrical.NRF}
  end
end
