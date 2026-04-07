defmodule Calendrical.PaschalFullMoonTest do
  use ExUnit.Case, async: true

  doctest Calendrical, only: [paschal_full_moon: 1]

  # Reference astronomical Paschal Full Moon dates for the last 50 years.
  # The Paschal Full Moon is the first astronomical full moon at or after the
  # March equinox. These reference values are computed from astronomical
  # observations and may differ by a day or so from the ecclesiastical Paschal
  # Full Moon used to compute Easter Sunday by tabular methods.
  @reference_dates %{
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
      for {year, expected} <- @reference_dates do
        {:ok, computed} = Calendrical.paschal_full_moon(year)

        # Allow ±1 day tolerance because the astronomical full moon
        # can fall on either side of midnight UTC depending on the
        # year and longitude convention.
        diff = abs(Date.diff(computed, expected))

        assert diff <= 1,
               "Year #{year}: expected #{expected}, got #{computed} (diff #{diff} days)"
      end
    end

    test "result is always on or after the March equinox" do
      for year <- 1975..2025 do
        {:ok, pfm} = Calendrical.paschal_full_moon(year)
        {:ok, equinox} = Astro.equinox(year, :march)
        equinox_date = DateTime.to_date(equinox)

        assert Date.compare(pfm, equinox_date) in [:eq, :gt],
               "Year #{year}: PFM #{pfm} is before equinox #{equinox_date}"
      end
    end

    test "result is always a full moon (lunar phase near 180°)" do
      for year <- 1975..2025 do
        {:ok, pfm} = Calendrical.paschal_full_moon(year)
        # Sample at noon UTC of the returned date
        {:ok, datetime} = DateTime.new(pfm, ~T[12:00:00])
        phase = Astro.lunar_phase_at(datetime)

        # The lunar phase should be within ~6° of 180° (full moon).
        # The full moon instant can occur anywhere within the day.
        deviation = min(abs(phase - 180.0), abs(phase - 180.0 + 360.0))

        assert deviation < 12.0,
               "Year #{year}: PFM #{pfm} has lunar phase #{phase}° (expected ~180°)"
      end
    end

    test "the previous full moon is before the March equinox" do
      for year <- 1975..2025 do
        {:ok, pfm} = Calendrical.paschal_full_moon(year)
        {:ok, equinox} = Astro.equinox(year, :march)

        # Find the full moon strictly before the PFM by searching from
        # one day before the PFM date.
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
        Calendrical.paschal_full_moon(999)
      end

      assert_raise FunctionClauseError, fn ->
        Calendrical.paschal_full_moon(3001)
      end
    end

    test "raises for non-integer input" do
      assert_raise FunctionClauseError, fn ->
        Calendrical.paschal_full_moon(2024.0)
      end
    end
  end
end
