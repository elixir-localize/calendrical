defmodule Calendrical.RoundTrip.Test do
  use ExUnit.Case, async: true

  # :calendar module doesn't work with year 0 or negative years
  test "that iso week of year is same as erlang" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Gregorian.days_in_month(year, month) do
      assert :calendar.iso_week_number({year, month, day}) ==
               Calendrical.Gregorian.iso_week_of_year(year, month, day)
    end
  end

  test "that Calendar.ISO dates and Calendrical.Gregorian dates are the same" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Gregorian.days_in_month(year, month) do
      {:ok, iso} = Date.new(year, month, day, Calendar.ISO)
      {:ok, gregorian} = Date.new(year, month, day, Calendrical.Gregorian)
      assert Date.compare(iso, gregorian) == :eq
    end
  end

  test "that Calendrical.Gregorian dates all round trip" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Gregorian.days_in_month(year, month) do
      {:ok, gregorian} = Date.new(year, month, day, Calendrical.Gregorian)
      {:ok, iso} = Date.convert(gregorian, Calendar.ISO)
      {:ok, converted} = Date.convert(iso, Calendrical.Gregorian)
      assert Date.compare(gregorian, converted) == :eq
    end
  end

  test "that Calendrical.ISOWeek dates all round trip" do
    for year <- 0001..2200,
        month <- 1..elem(Calendrical.ISOWeek.weeks_in_year(year), 0),
        day <- 1..7 do
      {:ok, iso_week} = Date.new(year, month, day, Calendrical.ISOWeek)
      {:ok, iso} = Date.convert(iso_week, Calendar.ISO)
      {:ok, converted} = Date.convert(iso, Calendrical.ISOWeek)
      assert Date.compare(iso_week, converted) == :eq
    end
  end

  test "that Calendrical.Fiscal.AU dates all round trip" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Fiscal.AU.days_in_month(year, month) do
      {:ok, au} = Date.new(year, month, day, Calendrical.Fiscal.AU)
      {:ok, iso} = Date.convert(au, Calendar.ISO)
      {:ok, converted} = Date.convert(iso, Calendrical.Fiscal.AU)
      assert Date.compare(au, converted) == :eq
    end
  end

  test "that Calendrical.Fiscal.UK dates all round trip" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Fiscal.UK.days_in_month(year, month) do
      {:ok, uk} = Date.new(year, month, day, Calendrical.Fiscal.UK)
      {:ok, iso} = Date.convert(uk, Calendar.ISO)
      {:ok, converted} = Date.convert(iso, Calendrical.Fiscal.UK)
      assert Date.compare(uk, converted) == :eq
    end
  end

  test "that Calendrical.Fiscal.US dates all round trip" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Fiscal.US.days_in_month(year, month) do
      {:ok, us} = Date.new(year, month, day, Calendrical.Fiscal.US)
      {:ok, iso} = Date.convert(us, Calendar.ISO)
      {:ok, converted} = Date.convert(iso, Calendrical.Fiscal.US)
      assert Date.compare(us, converted) == :eq
    end
  end

  test "that Calendrical.Julian dates all round trip" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Julian.days_in_month(year, month) do
      {:ok, julian} = Date.new(year, month, day, Calendrical.Julian)
      {:ok, iso} = Date.convert(julian, Calendar.ISO)
      {:ok, converted} = Date.convert(iso, Calendrical.Julian)
      assert Date.compare(julian, converted) == :eq
    end
  end

  test "that Calendrical.Julian.March25 dates all round trip" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..28 do
      {:ok, julian} = Date.new(year, month, day, Calendrical.Julian.March25)
      {:ok, iso} = Date.convert(julian, Calendar.ISO)
      {:ok, converted} = Date.convert(iso, Calendrical.Julian.March25)
      assert Date.compare(julian, converted) == :eq
    end
  end

  test "that Calendrical.Julian.Jan1 dates all round trip" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Julian.days_in_month(year, month) do
      {:ok, julian} = Date.new(year, month, day, Calendrical.Julian.Jan1)
      {:ok, iso} = Date.convert(julian, Calendar.ISO)
      {:ok, converted} = Date.convert(iso, Calendrical.Julian.Jan1)
      assert Date.compare(julian, converted) == :eq
    end
  end

  test "that Calendrical.Julian.Jan1 dates are the same as Calendrical.Julian dates" do
    for year <- 0001..2200,
        month <- 1..12,
        day <- 1..Calendrical.Julian.days_in_month(year, month) do
      {:ok, julian_jan1} = Date.new(year, month, day, Calendrical.Julian.Jan1)
      {:ok, julian} = Date.convert(julian_jan1, Calendrical.Julian)
      {:ok, converted} = Date.convert(julian, Calendrical.Julian.Jan1)
      assert Date.compare(julian_jan1, converted) == :eq
    end
  end
end
