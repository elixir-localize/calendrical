defmodule Calendrical.LawsTest do
  @moduledoc """
  The laws every calendar must satisfy, asserted for each of the
  library's calendars over a handful of its years.

  The laws are what a consumer such as Tempo relies on in place of
  knowing a calendar's kind: the day scale round-trips (1), a date's
  fields order the days (2), the months and the weeks tile the year
  (3), the labels agree with the periods (4), an absent period is an
  error (5), the year-less bounds bound the years and the numbers a year
  states are its dates (6), and a shift of nothing is nothing (7). `Calendrical.Laws` finds the failures of each;
  a passing law has none.

  Each calendar has a module of its own below, so its atlas of days is
  read once for all its laws. A law an existing calendar is known to
  break is tagged `known_failure` with the reason, and excluded from
  the default run so the suite stays green while the finding is ruled
  on: `mix test --include known_failure` runs them.

  """

  # The observational Islamic calendars reckon each month from a sighting
  # at a place and take tens of seconds a year, so they are not sampled.
  @sighting_calendars [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa]

  # Gregorian dates whose years each calendar is sampled at. Among them
  # are a leap year of the Gregorian calendar (2024), of the Hebrew
  # (5784, with Adar I) and of the Chinese (4660, with a leap month after
  # month 2), and a Coptic and Ethiopic leap year (1743 and 2019).
  @sample_dates [~D[2023-06-01], ~D[2024-03-01], ~D[2025-06-01], ~D[2026-10-01]]

  # Years a calendar is sampled at beside those: the years of England's
  # two reforms, and the Lady Day year that holds a 24-day thirteenth
  # month.
  @extra_years %{
    Calendrical.Reform.England => [1751, 1752],
    Calendrical.Julian.March25 => [1750]
  }

  # The laws an existing calendar breaks, by calendar and law, with the
  # reason: each is a finding for the user to rule on, not a defect of
  # the law test. See the moduledoc for how to run them. None at present:
  # England's gap in law 6 (its 1751 has the months 3 to 12, and its
  # September 1752 the days 1, 2 and 14 to 30) was answered on 2026-10-24
  # by holding the law to the numbers a calendar states, `month_numbers/1`
  # and `day_numbers/2`, rather than to a count from 1.
  @known_failures %{}

  sample_dates = @sample_dates
  extra_years = @extra_years
  known_failures = @known_failures

  # `Localize.Calendar.ISO` answers the behaviour for `Calendar.ISO` without
  # declaring it, since Localize does not depend on Calendrical, so the
  # laws are held to it here beside the library's own calendars.
  for calendar <- Calendrical.Laws.calendars(@sighting_calendars) ++ [Localize.Calendar.ISO] do
    defmodule Module.concat(__MODULE__, calendar) do
      use ExUnit.Case, async: true

      alias Calendrical.Laws

      @calendar calendar
      @years sample_dates
             |> Enum.map(&Laws.year_of(calendar, &1))
             |> Kernel.++(Map.get(extra_years, calendar, []))
             |> Enum.uniq()

      setup_all do
        {:ok,
         calendar: @calendar,
         years: @years,
         atlases: Map.new(@years, &{&1, Laws.atlas(@calendar, &1)})}
      end

      if reason = known_failures[{calendar, :round_trip}], do: @tag(known_failure: reason)

      test "1. the date of a day gives the day back, and is valid", %{atlases: atlases} do
        for {year, atlas} <- atlases do
          assert Laws.round_trip_failures(atlas) == [], "in #{year}"
        end
      end

      if reason = known_failures[{calendar, :order}], do: @tag(known_failure: reason)

      test "2. the dates of consecutive days are in lexicographic order", %{atlases: atlases} do
        for {year, atlas} <- atlases do
          assert Laws.order_failures(atlas) == [], "in #{year}"
        end
      end

      if reason = known_failures[{calendar, :months_tile}], do: @tag(known_failure: reason)

      test "3. the months walked through month/2 tile the year",
           %{calendar: calendar, years: years} do
        for year <- years do
          first..last//1 = Laws.days_of_year(calendar, year)
          walked = Laws.months_walked(calendar, year)
          assert match?({:ok, _months}, walked), "in #{year}: #{inspect(walked)}"
          {:ok, months} = walked
          assert Laws.tiling_failures(months, first, last) == [], "in #{year}"
        end
      end

      if reason = known_failures[{calendar, :weeks_tile}], do: @tag(known_failure: reason)

      test "3. the weeks of a week-year tile it, and the week-years abut",
           %{calendar: calendar, years: years} do
        for year <- years do
          weeks = Laws.weeks_of_year(calendar, year)
          assert match?([{1, %Date.Range{}} | _rest], weeks), "in #{year}: #{inspect(weeks)}"
          [{1, %Date.Range{first_in_iso_days: first}} | _rest] = weeks
          {_last_week, %Date.Range{last_in_iso_days: last}} = List.last(weeks)
          assert Laws.tiling_failures(weeks, first, last) == [], "in #{year}"

          next_week = calendar.week(year + 1, 1)
          assert match?(%Date.Range{}, next_week), "week 1 of #{year + 1}: #{inspect(next_week)}"
          %Date.Range{first_in_iso_days: next_first} = next_week
          assert next_first == last + 1, "week-years #{year} and #{year + 1} do not abut"
        end
      end

      if reason = known_failures[{calendar, :week_labels}], do: @tag(known_failure: reason)

      test "4. week_of_year/3 names the week of week/2 that holds the day",
           %{calendar: calendar, atlases: atlases} do
        for {year, atlas} <- atlases do
          assert Laws.week_label_failures(calendar, atlas) == [], "in #{year}"
        end
      end

      if reason = known_failures[{calendar, :day_of_week}], do: @tag(known_failure: reason)

      test "4. the day of the week runs 1 to 7 over seven consecutive days",
           %{atlases: atlases} do
        for {year, atlas} <- atlases do
          assert Laws.day_of_week_failures(atlas) == [], "in #{year}"
        end
      end

      if reason = known_failures[{calendar, :absent}], do: @tag(known_failure: reason)

      test "5. a month, week or quarter the year does not have is an error",
           %{calendar: calendar, years: years} do
        for year <- years do
          periods = Laws.absent_periods(calendar, year)
          assert Laws.present_period_failures(calendar, periods) == [], "in #{year}"
        end
      end

      if reason = known_failures[{calendar, :bounds}], do: @tag(known_failure: reason)

      test "6. the year-less bounds hold every sampled year's months and every month's days",
           %{calendar: calendar, years: years} do
        assert {fewest_months, most_months} = calendar.months_in_year_bounds()

        for year <- years do
          {:ok, months} = Laws.months_walked(calendar, year)

          assert length(months) in fewest_months..most_months,
                 "#{year} has #{length(months)} months"

          for {{^year, month}, range} <- months do
            bounds = calendar.days_in_month_bounds(month)
            assert match?({_fewest, _most}, bounds), "month #{month}: #{inspect(bounds)}"
            {fewest, most} = bounds

            assert Laws.days_in(range) in fewest..most,
                   "month #{month} of #{year} has #{Laws.days_in(range)} days"
          end
        end
      end

      if reason = known_failures[{calendar, :numbers}], do: @tag(known_failure: reason)

      # A year's months, and a month's days, are the numbers the calendar
      # states, which run from 1 without a gap in every calendar but a
      # composite: England's 1751 is the months 3 to 12. Each is a period
      # the calendar has, and their counts are within the year-less bounds.
      test "6. the month and day numbers a year states are its months and days, within the bounds",
           %{calendar: calendar, years: years} do
        for year <- years do
          assert Laws.number_failures(calendar, year) == [], "in #{year}"
        end
      end

      if reason = known_failures[{calendar, :shift}], do: @tag(known_failure: reason)

      test "7. a shift of nothing is the date, and a shift is a valid date",
           %{calendar: calendar, atlases: atlases} do
        for {year, atlas} <- atlases do
          assert Laws.shift_failures(calendar, atlas) == [], "in #{year}"
        end
      end
    end
  end
end
