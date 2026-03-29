defmodule Calendrical.Test do
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

  test "that persian, coptic and ethopic calendar date exists" do
    assert {:ok, _} = Calendrical.eras(:en, :persian)
    assert {:ok, _} = Calendrical.eras(:en, :coptic)
    assert {:ok, _} = Calendrical.eras(:en, :ethiopic)
  end

  test "that we default the year and calendar when localizing a partial date that has only a month" do
    assert "January" = Calendrical.localize(%{month: 1}, :month, format: :wide)
  end

  test "stand alone month names are resolved" do
    assert %{1 => "Jan"} = Calendrical.month_names(Calendrical.Gregorian, type: :stand_alone)
  end
end
