defmodule Calendrical.ISOWeek.Test do
  use ExUnit.Case, async: true

  test "the configuration of ISOWeek calendar" do
    config = %Calendrical.Config{
      begins_or_ends: :begins,
      calendar: Calendrical.ISOWeek,
      day_of_week: 1,
      first_or_last: :first,
      min_days_in_first_week: 4,
      month_of_year: 1,
      weeks_in_month: [4, 5, 4],
      year: :majority
    }

    assert Calendrical.ISOWeek.__config__() == config
  end

  # A calendar of weeks' months are the unnamed periods of its pattern of
  # weeks, so CLDR's generic calendar names them, "M01" to "M12" in root,
  # while its days and eras keep the Gregorian names. 16 June 2026 is ISO
  # 2026-W25-2, in the sixth 4-5-4 period (weeks 23 to 26), and NRF
  # 2026-W20-3, in its fifth (weeks 18 to 22).
  test "a calendar of weeks names its months from CLDR's generic calendar" do
    for {calendar, month} <- [{Calendrical.ISOWeek, "M06"}, {Calendrical.NRF, "M05"}] do
      date = Date.convert!(~D[2026-06-16], calendar)

      assert calendar.cldr_calendar_type() == :generic
      assert calendar.era_calendar_type() == :gregorian
      assert Calendrical.localize(date, :month, locale: :en) == month
      assert Calendrical.localize(date, :day_of_week, locale: :en) == "Tue"
      assert Calendrical.localize(date, :era, locale: :en) == "AD"
    end
  end
end
