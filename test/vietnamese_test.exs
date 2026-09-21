defmodule Calendrical.Vietnamese.Test do
  use ExUnit.Case, async: true

  doctest Calendrical.Vietnamese

  alias Calendrical.{Chinese, Vietnamese}

  # The Vietnamese calendar is the Chinese lunisolar calendar observed at
  # 105°E (UTC+7) rather than Beijing. The documented divergences from the
  # Chinese New Year are the acceptance criteria for the meridian offset.
  describe "Tết vs Chinese New Year (offset-meridian acceptance)" do
    test "1985: Tết is a full month before the Chinese New Year" do
      assert Vietnamese.tet_for_gregorian_year(1985) == ~D[1985-01-21]
      assert Chinese.gregorian_date_for_lunar(1985, 1, 1) == ~D[1985-02-20]
    end

    test "2007, 2030 and 2053: Tết is one day before the Chinese New Year" do
      assert Vietnamese.tet_for_gregorian_year(2007) == ~D[2007-02-17]
      assert Chinese.gregorian_date_for_lunar(2007, 1, 1) == ~D[2007-02-18]

      assert Vietnamese.tet_for_gregorian_year(2030) == ~D[2030-02-02]
      assert Chinese.gregorian_date_for_lunar(2030, 1, 1) == ~D[2030-02-03]

      assert Vietnamese.tet_for_gregorian_year(2053) == ~D[2053-02-18]
      assert Chinese.gregorian_date_for_lunar(2053, 1, 1) == ~D[2053-02-19]
    end

    test "in a non-divergence year Tết coincides with the Chinese New Year" do
      for year <- [2021, 2022, 2023, 2024, 2025] do
        assert Vietnamese.tet_for_gregorian_year(year) ==
                 Chinese.gregorian_date_for_lunar(year, 1, 1),
               "expected Tết #{year} to equal the Chinese New Year"
      end
    end
  end

  describe "preference resolution" do
    alias Calendrical.Preference

    test "a Vietnamese locale requesting the chinese calendar resolves to Vietnamese" do
      assert Preference.calendar_from_locale("vi-u-ca-chinese") == {:ok, Vietnamese}
      assert Preference.calendar_from_territory(:VN, :chinese) == {:ok, Vietnamese}
    end

    test "the VN civil default is unchanged (Gregorian), and other territories are untouched" do
      assert Preference.calendar_from_territory(:VN) == {:ok, Calendrical.Gregorian}
      assert Preference.calendar_from_locale("vi") == {:ok, Calendrical.Gregorian}
      assert Preference.calendar_from_locale("zh-u-ca-chinese") == {:ok, Chinese}
    end
  end

  describe "conversion round-trips" do
    test "iso-day round-trip across a range of dates" do
      for iso_days <- Enum.take_every(730_000..745_000, 137) do
        {year, month, day} = Vietnamese.date_from_iso_days(iso_days)
        assert Vietnamese.date_to_iso_days(year, month, day) == iso_days
      end
    end

    test "before 1968 the calendar is identical to the Chinese calendar" do
      # Vietnam followed the Chinese calendar until the 1968 UTC+7 switch, so
      # every pre-1968 date — including the pre-1929 Beijing-local-meridian
      # era and the 1929-1968 UTC+8 era — matches Calendrical.Chinese exactly.
      start = Calendrical.Gregorian.date_to_iso_days(1850, 1, 1)
      stop = Calendrical.Gregorian.date_to_iso_days(1967, 12, 31)

      for iso_days <- Enum.take_every(start..stop, 379) do
        assert Vietnamese.date_from_iso_days(iso_days) ==
                 Chinese.date_from_iso_days(iso_days)
      end

      # New Year agreement across both pre-1968 eras.
      for year <- [1850, 1900, 1928, 1929, 1950, 1967] do
        assert Vietnamese.tet_for_gregorian_year(year) ==
                 Chinese.gregorian_date_for_lunar(year, 1, 1)
      end
    end
  end
end
