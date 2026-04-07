defmodule Calendrical.Ethiopic.AmeteAlemTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Ethiopic.AmeteAlem

  alias Calendrical.Ethiopic.AmeteAlem

  describe "year offset" do
    test "Amete Alem year is 5500 ahead of Amete Mihret" do
      assert AmeteAlem.era_offset() == 5500
      assert AmeteAlem.amete_mihret_year(7517) == 2017
      assert AmeteAlem.amete_alem_year(2017) == 7517
    end
  end

  describe "round-trip conversions" do
    test "1 Meskerem 7517 AA = 11 September 2024 (Ethiopian New Year)" do
      {:ok, aa} = Date.new(7517, 1, 1, AmeteAlem)
      {:ok, gregorian} = Date.convert(aa, Calendrical.Gregorian)
      assert gregorian == ~D[2024-09-11 Calendrical.Gregorian]
    end

    test "round-trips a recent Gregorian date" do
      {:ok, gregorian} = Date.new(2024, 7, 15, Calendrical.Gregorian)
      {:ok, aa} = Date.convert(gregorian, AmeteAlem)
      {:ok, back} = Date.convert(aa, Calendrical.Gregorian)
      assert back == gregorian
    end

    test "Amete Alem date matches Amete Mihret with year offset" do
      {:ok, gregorian} = Date.new(2024, 7, 15, Calendrical.Gregorian)
      {:ok, aa} = Date.convert(gregorian, AmeteAlem)
      {:ok, am} = Date.convert(gregorian, Calendrical.Ethiopic)

      assert aa.year == am.year + 5500
      assert aa.month == am.month
      assert aa.day == am.day
    end

    test "round-trips 50 random Gregorian dates" do
      :rand.seed(:exsss, {21, 22, 23})

      for _ <- 1..50 do
        iso_days = Enum.random(50_000..900_000)
        gregorian = Date.from_gregorian_days(iso_days)
        gregorian = %{gregorian | calendar: Calendrical.Gregorian}

        {:ok, aa} = Date.convert(gregorian, AmeteAlem)
        {:ok, back} = Date.convert(aa, Calendrical.Gregorian)
        assert back == gregorian
      end
    end
  end

  describe "leap_year? and days_in_month" do
    test "leap years follow the Ethiopic rule mod(year, 4) == 3 with offset" do
      # Ethiopic year 2015 (= AA 7515) is a leap year (2015 mod 4 == 3)
      assert AmeteAlem.leap_year?(7515)
      refute AmeteAlem.leap_year?(7516)
      refute AmeteAlem.leap_year?(7517)
      refute AmeteAlem.leap_year?(7518)
      assert AmeteAlem.leap_year?(7519)
    end

    test "month 13 (Pagumen) has 5 or 6 days" do
      assert AmeteAlem.days_in_month(7515, 13) == 6
      assert AmeteAlem.days_in_month(7516, 13) == 5
    end

    test "months 1-12 have 30 days" do
      for month <- 1..12 do
        assert AmeteAlem.days_in_month(7517, month) == 30
      end
    end
  end

  # ── Localization ─────────────────────────────────────────────────────────

  describe "month name localization" do
    test "English month names" do
      cases = [
        {1, "Meskerem"},
        {6, "Yekatit"},
        {12, "Nehasse"},
        {13, "Pagumen"}
      ]

      for {month, expected} <- cases do
        {:ok, date} = Date.new(7517, month, 1, AmeteAlem)
        assert Calendrical.localize(date, :month, locale: "en", format: :wide) == expected
      end
    end
  end

  describe "day-of-week localization" do
    test "English day name" do
      # 1 Meskerem 7517 AA = 11 September 2024 = Wednesday
      {:ok, date} = Date.new(7517, 1, 1, AmeteAlem)

      assert Calendrical.localize(date, :day_of_week, locale: "en", format: :wide) ==
               "Wednesday"
    end
  end
end
