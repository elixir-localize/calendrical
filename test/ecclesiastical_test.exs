defmodule Calendrical.EcclesiasticalTest do
  use ExUnit.Case, async: true

  doctest Calendrical.Ecclesiastical

  alias Calendrical.Ecclesiastical

  # ── Western Easter (Gregorian computus) ────────────────────────────────

  describe "easter_sunday/1" do
    test "spot checks: known Western Easter dates" do
      cases = [
        {2020, ~D[2020-04-12]},
        {2021, ~D[2021-04-04]},
        {2022, ~D[2022-04-17]},
        {2023, ~D[2023-04-09]},
        {2024, ~D[2024-03-31]},
        {2025, ~D[2025-04-20]},
        {2026, ~D[2026-04-05]},
        {2027, ~D[2027-03-28]},
        {2028, ~D[2028-04-16]}
      ]

      for {year, expected} <- cases do
        result = Ecclesiastical.easter_sunday(year)
        result_iso = %{result | calendar: Calendar.ISO}
        assert result_iso == expected, "Year #{year}: got #{result_iso}, expected #{expected}"
      end
    end

    test "always returns a Sunday in Calendrical.Gregorian" do
      for year <- 2000..2030 do
        date = Ecclesiastical.easter_sunday(year)
        assert date.calendar == Calendrical.Gregorian
        iso = %{date | calendar: Calendar.ISO}
        assert Date.day_of_week(iso) == 7
      end
    end

    test "Easter falls between March 22 and April 25 (inclusive)" do
      for year <- 1900..2100 do
        date = Ecclesiastical.easter_sunday(year)
        iso = %{date | calendar: Calendar.ISO}
        early = Date.new!(year, 3, 22)
        late = Date.new!(year, 4, 25)
        assert Date.compare(iso, early) in [:eq, :gt]
        assert Date.compare(iso, late) in [:eq, :lt]
      end
    end
  end

  describe "good_friday/1" do
    test "is exactly 2 days before easter_sunday/1" do
      for year <- 2000..2030 do
        gf = Ecclesiastical.good_friday(year)
        es = Ecclesiastical.easter_sunday(year)
        assert Date.diff(es, gf) == 2
      end
    end

    test "always returns a Friday in Calendrical.Gregorian" do
      for year <- 2000..2030 do
        date = Ecclesiastical.good_friday(year)
        assert date.calendar == Calendrical.Gregorian
        iso = %{date | calendar: Calendar.ISO}
        assert Date.day_of_week(iso) == 5
      end
    end
  end

  # ── Eastern Orthodox Easter (Julian computus) ──────────────────────────

  describe "orthodox_easter_sunday/1" do
    test "returns dates in Calendrical.Julian" do
      for year <- 2020..2030 do
        date = Ecclesiastical.orthodox_easter_sunday(year)
        assert date.calendar == Calendrical.Julian
      end
    end

    test "always returns a Sunday" do
      for year <- 2000..2030 do
        date = Ecclesiastical.orthodox_easter_sunday(year)
        {:ok, gregorian} = Date.convert(date, Calendrical.Gregorian)
        iso = %{gregorian | calendar: Calendar.ISO}
        assert Date.day_of_week(iso) == 7
      end
    end

    test "spot checks: known Orthodox Easter Julian dates" do
      cases = [
        {2024, ~D[2024-04-22 Calendrical.Julian]},
        {2025, ~D[2025-04-07 Calendrical.Julian]},
        {2026, ~D[2026-03-30 Calendrical.Julian]}
      ]

      for {year, expected} <- cases do
        assert Ecclesiastical.orthodox_easter_sunday(year) == expected
      end
    end

    test "spot checks: corresponding Gregorian projection" do
      cases = [
        {2020, ~D[2020-04-19]},
        {2021, ~D[2021-05-02]},
        {2022, ~D[2022-04-24]},
        {2023, ~D[2023-04-16]},
        {2024, ~D[2024-05-05]},
        # 2025 is a year of coincidence with Western
        {2025, ~D[2025-04-20]},
        {2026, ~D[2026-04-12]}
      ]

      for {year, expected} <- cases do
        date = Ecclesiastical.orthodox_easter_sunday(year)
        {:ok, gregorian} = Date.convert(date, Calendrical.Gregorian)
        result_iso = %{gregorian | calendar: Calendar.ISO}
        assert result_iso == expected, "Year #{year}: got #{result_iso}, expected #{expected}"
      end
    end
  end

  describe "orthodox_good_friday/1" do
    test "is exactly 2 days before orthodox_easter_sunday/1" do
      for year <- 2000..2030 do
        gf = Ecclesiastical.orthodox_good_friday(year)
        es = Ecclesiastical.orthodox_easter_sunday(year)
        assert Date.diff(es, gf) == 2
      end
    end

    test "always returns a Friday in Calendrical.Julian" do
      for year <- 2020..2030 do
        date = Ecclesiastical.orthodox_good_friday(year)
        assert date.calendar == Calendrical.Julian
        {:ok, gregorian} = Date.convert(date, Calendrical.Gregorian)
        iso = %{gregorian | calendar: Calendar.ISO}
        assert Date.day_of_week(iso) == 5
      end
    end
  end

  # ── Pentecost (Western and Orthodox) ───────────────────────────────────

  describe "pentecost/1 (Western)" do
    test "is exactly 49 days after Western easter_sunday/1" do
      for year <- 2000..2030 do
        easter = Ecclesiastical.easter_sunday(year)
        pentecost = Ecclesiastical.pentecost(year)
        assert Date.diff(pentecost, easter) == 49
      end
    end

    test "always returns a Sunday in Calendrical.Gregorian" do
      for year <- 2020..2030 do
        date = Ecclesiastical.pentecost(year)
        assert date.calendar == Calendrical.Gregorian
        iso = %{date | calendar: Calendar.ISO}
        assert Date.day_of_week(iso) == 7
      end
    end
  end

  describe "orthodox_pentecost/1" do
    test "is exactly 49 days after orthodox_easter_sunday/1" do
      for year <- 2020..2030 do
        easter = Ecclesiastical.orthodox_easter_sunday(year)
        pentecost = Ecclesiastical.orthodox_pentecost(year)
        assert Date.diff(pentecost, easter) == 49
      end
    end

    test "always returns a Sunday in Calendrical.Julian" do
      for year <- 2020..2030 do
        date = Ecclesiastical.orthodox_pentecost(year)
        assert date.calendar == Calendrical.Julian
        {:ok, gregorian} = Date.convert(date, Calendrical.Gregorian)
        iso = %{gregorian | calendar: Calendar.ISO}
        assert Date.day_of_week(iso) == 7
      end
    end
  end

  # ── Advent (Western) and Nativity Fast (Orthodox) ──────────────────────

  describe "advent/1 (Western)" do
    test "is the Sunday closest to 30 November" do
      for year <- 2020..2030 do
        date = Ecclesiastical.advent(year)
        assert date.calendar == Calendrical.Gregorian
        iso = %{date | calendar: Calendar.ISO}
        assert Date.day_of_week(iso) == 7
        nov_30 = Date.new!(year, 11, 30)
        diff = abs(Date.diff(iso, nov_30))
        assert diff <= 3
      end
    end

    test "spot checks: 2024 = Dec 1, 2025 = Nov 30" do
      assert %{year: 2024, month: 12, day: 1} = Ecclesiastical.advent(2024)
      assert %{year: 2025, month: 11, day: 30} = Ecclesiastical.advent(2025)
    end
  end

  describe "orthodox_advent/1" do
    test "always returns 15 November in Calendrical.Julian" do
      for year <- 2020..2030 do
        date = Ecclesiastical.orthodox_advent(year)
        assert date.calendar == Calendrical.Julian
        assert date.year == year
        assert date.month == 11
        assert date.day == 15
      end
    end

    test "corresponds to 28 November Gregorian for current 13-day offset" do
      date = Ecclesiastical.orthodox_advent(2024)
      {:ok, gregorian} = Date.convert(date, Calendrical.Gregorian)
      assert gregorian.month == 11
      assert gregorian.day == 28
    end
  end

  # ── Christmas ──────────────────────────────────────────────────────────

  describe "christmas/1" do
    test "always returns 25 December" do
      for year <- 2020..2030 do
        date = Ecclesiastical.christmas(year)
        assert date.year == year
        assert date.month == 12
        assert date.day == 25
      end
    end
  end

  # ── Epiphany ───────────────────────────────────────────────────────────

  describe "epiphany/1" do
    test "is the first Sunday after January 1" do
      for year <- 2020..2030 do
        date = Ecclesiastical.epiphany(year)
        iso = %{date | calendar: Calendar.ISO}
        assert Date.day_of_week(iso) == 7
        assert iso.month == 1
        assert iso.day in 2..8
      end
    end
  end

  # ── Eastern Orthodox Christmas ─────────────────────────────────────────

  describe "eastern_orthodox_christmas/1" do
    test "is 7 January for recent years" do
      for year <- 2020..2030 do
        result = Ecclesiastical.eastern_orthodox_christmas(year)
        assert is_list(result)
        assert length(result) >= 1

        for date <- result do
          iso = %{date | calendar: Calendar.ISO}
          assert iso.month == 1 and iso.day == 7
        end
      end
    end
  end

  # ── Coptic Christmas ──────────────────────────────────────────────────

  describe "coptic_christmas/1" do
    test "is 7 or 8 January for recent years" do
      for year <- 2020..2030 do
        result = Ecclesiastical.coptic_christmas(year)
        assert is_list(result)
        assert length(result) >= 1

        for date <- result do
          iso = %{date | calendar: Calendar.ISO}
          assert iso.month == 1
          assert iso.day in [7, 8]
        end
      end
    end
  end

  # ── Astronomical (WCC 1997) Easter ─────────────────────────────────────

  describe "astronomical_easter_sunday/1" do
    test "spot checks: 2020-2030 (matches Western for these years)" do
      cases = [
        {2020, ~D[2020-04-12]},
        {2021, ~D[2021-04-04]},
        {2022, ~D[2022-04-17]},
        {2023, ~D[2023-04-09]},
        {2024, ~D[2024-03-31]},
        {2025, ~D[2025-04-20]},
        {2026, ~D[2026-04-05]},
        {2027, ~D[2027-03-28]},
        {2028, ~D[2028-04-16]},
        {2029, ~D[2029-04-01]},
        {2030, ~D[2030-04-21]}
      ]

      for {year, expected} <- cases do
        {:ok, result} = Ecclesiastical.astronomical_easter_sunday(year)
        assert result == expected, "Year #{year}: got #{result}, expected #{expected}"
      end
    end

    test "always returns a Sunday" do
      for year <- 2000..2030 do
        {:ok, date} = Ecclesiastical.astronomical_easter_sunday(year)
        assert Date.day_of_week(date) == 7
      end
    end

    test "is always strictly after the astronomical Paschal Full Moon" do
      for year <- 1980..2030 do
        {:ok, easter} = Ecclesiastical.astronomical_easter_sunday(year)
        {:ok, pfm} = Ecclesiastical.paschal_full_moon(year)
        assert Date.compare(easter, pfm) == :gt
        assert Date.diff(easter, pfm) in 1..7
      end
    end

    test "raises for years outside the supported range" do
      assert_raise FunctionClauseError, fn ->
        Ecclesiastical.astronomical_easter_sunday(999)
      end

      assert_raise FunctionClauseError, fn ->
        Ecclesiastical.astronomical_easter_sunday(3001)
      end
    end
  end

  describe "astronomical_good_friday/1" do
    test "is exactly 2 days before astronomical_easter_sunday/1" do
      for year <- 2000..2030 do
        {:ok, gf} = Ecclesiastical.astronomical_good_friday(year)
        {:ok, es} = Ecclesiastical.astronomical_easter_sunday(year)
        assert Date.diff(es, gf) == 2
      end
    end

    test "always returns a Friday" do
      for year <- 2000..2030 do
        {:ok, date} = Ecclesiastical.astronomical_good_friday(year)
        assert Date.day_of_week(date) == 5
      end
    end

    test "raises for years outside the supported range" do
      assert_raise FunctionClauseError, fn ->
        Ecclesiastical.astronomical_good_friday(999)
      end
    end
  end

  # ── Astronomical Paschal Full Moon ─────────────────────────────────────

  # Reference astronomical Paschal Full Moon dates for the last 50 years.
  @paschal_reference_dates %{
    1976 => ~D[1976-04-14],
    1977 => ~D[1977-04-03],
    1978 => ~D[1978-03-24],
    1979 => ~D[1979-04-12],
    1980 => ~D[1980-03-31],
    1981 => ~D[1981-04-19],
    1982 => ~D[1982-04-08],
    1983 => ~D[1983-03-28],
    1984 => ~D[1984-04-15],
    1985 => ~D[1985-04-04],
    1986 => ~D[1986-03-25],
    1987 => ~D[1987-04-13],
    1988 => ~D[1988-04-02],
    1989 => ~D[1989-03-22],
    1990 => ~D[1990-04-10],
    1991 => ~D[1991-03-30],
    1992 => ~D[1992-04-17],
    1993 => ~D[1993-04-06],
    1994 => ~D[1994-03-27],
    1995 => ~D[1995-04-15],
    1996 => ~D[1996-04-04],
    1997 => ~D[1997-03-23],
    1998 => ~D[1998-04-11],
    1999 => ~D[1999-03-31],
    2000 => ~D[2000-04-18],
    2001 => ~D[2001-04-08],
    2002 => ~D[2002-03-28],
    2003 => ~D[2003-04-16],
    2004 => ~D[2004-04-05],
    2005 => ~D[2005-03-25],
    2006 => ~D[2006-04-13],
    2007 => ~D[2007-04-02],
    2008 => ~D[2008-03-21],
    2009 => ~D[2009-04-09],
    2010 => ~D[2010-03-30],
    2011 => ~D[2011-04-18],
    2012 => ~D[2012-04-06],
    2013 => ~D[2013-03-27],
    2014 => ~D[2014-04-15],
    2015 => ~D[2015-04-04],
    2016 => ~D[2016-03-23],
    2017 => ~D[2017-04-11],
    2018 => ~D[2018-03-31],
    2019 => ~D[2019-03-21],
    2020 => ~D[2020-04-08],
    2021 => ~D[2021-03-28],
    2022 => ~D[2022-04-16],
    2023 => ~D[2023-04-06],
    2024 => ~D[2024-03-25],
    2025 => ~D[2025-04-13]
  }

  describe "paschal_full_moon/1" do
    test "computes the Paschal Full Moon for the last 50 years" do
      for {year, expected} <- @paschal_reference_dates do
        {:ok, computed} = Ecclesiastical.paschal_full_moon(year)
        diff = abs(Date.diff(computed, expected))

        assert diff <= 1,
               "Year #{year}: expected #{expected}, got #{computed} (diff #{diff} days)"
      end
    end

    test "result is always on or after the March equinox" do
      for year <- 1975..2025 do
        {:ok, pfm} = Ecclesiastical.paschal_full_moon(year)
        {:ok, equinox} = Astro.equinox(year, :march)
        equinox_date = DateTime.to_date(equinox)

        assert Date.compare(pfm, equinox_date) in [:eq, :gt],
               "Year #{year}: PFM #{pfm} is before equinox #{equinox_date}"
      end
    end

    test "result is always a full moon (lunar phase near 180°)" do
      for year <- 1975..2025 do
        {:ok, pfm} = Ecclesiastical.paschal_full_moon(year)
        {:ok, datetime} = DateTime.new(pfm, ~T[12:00:00])
        phase = Astro.lunar_phase_at(datetime)
        deviation = min(abs(phase - 180.0), abs(phase - 180.0 + 360.0))

        assert deviation < 12.0,
               "Year #{year}: PFM #{pfm} has lunar phase #{phase}° (expected ~180°)"
      end
    end

    test "the previous full moon is before the March equinox" do
      for year <- 1975..2025 do
        {:ok, pfm} = Ecclesiastical.paschal_full_moon(year)
        {:ok, equinox} = Astro.equinox(year, :march)
        previous_search_from = Date.add(pfm, -1)

        {:ok, previous_full_moon} =
          Astro.date_time_lunar_phase_at_or_before(
            previous_search_from,
            Astro.Lunar.full_moon_phase()
          )

        assert DateTime.compare(previous_full_moon, equinox) == :lt,
               "Year #{year}: previous full moon #{previous_full_moon} is not before equinox #{equinox}"
      end
    end

    test "raises for years outside the supported range" do
      assert_raise FunctionClauseError, fn ->
        Ecclesiastical.paschal_full_moon(999)
      end

      assert_raise FunctionClauseError, fn ->
        Ecclesiastical.paschal_full_moon(3001)
      end
    end

    test "raises for non-integer input" do
      assert_raise FunctionClauseError, fn ->
        Ecclesiastical.paschal_full_moon(2024.0)
      end
    end
  end
end
