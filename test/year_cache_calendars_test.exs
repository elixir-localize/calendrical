defmodule Calendrical.YearCacheCalendarsTest do
  # The calendars reckoned by astronomy keep what they work out about a year
  # (`Calendrical.YearCache`). Every answer must be the same from the kept
  # years as from the astronomy worked out afresh, whatever order the days
  # come in. A day's date is found from the kept new years and month starts
  # around it, so it is also held to the new year and the month start the
  # astronomy finds from the day itself. Not async: it clears the cache.
  use ExUnit.Case, async: false

  alias Calendrical.YearCache

  @lunisolar [
    Calendrical.Chinese,
    Calendrical.Korean,
    Calendrical.Vietnamese,
    Calendrical.LunarJapanese
  ]

  # Days spread over the years of the ephemeris and beyond it, in an order
  # that moves within years, to neighbouring years and across centuries.
  defp days(count, first, last) do
    first = Date.to_gregorian_days(first)
    span = Date.to_gregorian_days(last) - first

    for i <- 1..count, do: first + rem(i * 7_919 + i * i * 104_729, span)
  end

  # Every question asked in turn, the cache keeping what each works out for
  # the ones after it; then each again on an empty cache.
  defp assert_same_from_kept_and_fresh(questions) do
    kept = for {label, question} <- questions, do: {label, answer(question)}

    fresh =
      for {label, question} <- questions do
        YearCache.clear()
        {label, answer(question)}
      end

    for {{label, kept_answer}, {_label, fresh_answer}} <- Enum.zip(kept, fresh) do
      assert kept_answer == fresh_answer, label
    end
  end

  defp answer(question) do
    question.()
  rescue
    exception -> {:raised, exception.__struct__}
  end

  test "the Persian calendar" do
    years = Enum.concat(1275..1485//3, [-500, 1278, 1279, 1479, 1480, 3000])

    assert_same_from_kept_and_fresh(
      for(
        d <- days(300, ~D[1890-01-01], ~D[2110-12-31]) ++ days(40, ~D[0001-01-01], ~D[3000-12-31]),
        do: {"from #{d}", fn -> Calendrical.Persian.date_from_iso_days(d) end}
      ) ++
        for(
          y <- years,
          do:
            {"year #{y}",
             fn ->
               {Calendrical.Persian.leap_year?(y),
                Calendrical.Persian.date_to_iso_days(y, 12, 29)}
             end}
        )
    )
  end

  test "the lunisolar calendars" do
    for calendar <- @lunisolar do
      {year, _month, _day} = calendar.date_from_iso_days(Date.to_gregorian_days(~D[2000-06-01]))

      days =
        days(250, ~D[1890-01-01], ~D[2110-12-31]) ++ days(50, ~D[-2000-01-01], ~D[4000-12-31])

      years = Enum.concat((year - 110)..(year + 110)//11, [year - 3000, year + 2000])

      assert_same_from_kept_and_fresh(
        for(
          d <- days,
          do: {"#{inspect(calendar)} from #{d}", fn -> calendar.date_from_iso_days(d) end}
        ) ++
          for y <- years, month <- 1..13 do
            {"#{inspect(calendar)} #{y} #{month}",
             fn ->
               {calendar.days_in_month(y, month), calendar.valid_date?(y, month, 30),
                calendar.date_to_iso_days(y, month, 1), calendar.leap_month(y),
                calendar.months_in_year(y), calendar.days_in_year(y),
                calendar.solar_term(2 * month - 1, 1900 + rem(y, 200))}
             end}
          end
      )
    end
  end

  test "a lunisolar day's new year and month start are those found from the day itself" do
    for calendar <- @lunisolar,
        d <-
          days(150, ~D[1890-01-01], ~D[2110-12-31]) ++ days(30, ~D[-2000-01-01], ~D[4000-12-31]) do
      location = &calendar.location/1
      {year, month, day} = calendar.date_from_iso_days(d)
      new_year = Calendrical.Lunisolar.new_year_on_or_before(d, location)
      start_of_month = Calendrical.Lunisolar.new_moon_before(d + 1, location)

      assert calendar.date_to_iso_days(year, 1, 1) == new_year, "#{inspect(calendar)} #{d}"
      assert day == d - start_of_month + 1, "#{inspect(calendar)} #{d}"

      assert month == round((start_of_month - new_year) / Astro.Time.mean_synodic_month() + 1),
             "#{inspect(calendar)} #{d}"
    end
  end

  @tag :full
  test "an observational Islamic day's month begins on the crescent found from the day itself" do
    # Days spread over the ephemeris, and the days at its ends, where a
    # day's own crescent search can leave it and raise.
    edges =
      Enum.concat(
        Date.to_gregorian_days(~D[1900-01-01])..Date.to_gregorian_days(~D[1900-03-15])//3,
        Date.to_gregorian_days(~D[2100-11-15])..Date.to_gregorian_days(~D[2101-02-10])//2
      )

    for calendar <- [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa],
        d <- days(40, ~D[1900-03-01], ~D[2100-11-30]) ++ edges do
      day =
        answer(fn ->
          {_year, _month, day} = calendar.date_from_iso_days(d)
          day
        end)

      from_the_day =
        answer(fn ->
          d - Calendrical.Islamic.Visibility.phasis_on_or_before(d, calendar.location()) + 1
        end)

      assert day == from_the_day, "#{inspect(calendar)} #{d}"
    end
  end

  @tag :full
  test "the observational Islamic calendars" do
    for calendar <- [Calendrical.Islamic.Observational, Calendrical.Islamic.Rgsa] do
      # The ephemeris's first and last months, and days outside it.
      days =
        days(60, ~D[1900-01-01], ~D[2100-12-31]) ++
          for date <- [
                ~D[1899-12-01],
                ~D[1900-01-01],
                ~D[1900-03-15],
                ~D[2100-12-15],
                ~D[2101-02-01]
              ],
              do: Date.to_gregorian_days(date)

      assert_same_from_kept_and_fresh(
        for(
          d <- days,
          do: {"#{inspect(calendar)} from #{d}", fn -> calendar.date_from_iso_days(d) end}
        ) ++
          for y <- [1317, 1318, 1400, 1445, 1524, 1525], month <- [1, 6, 12] do
            {"#{inspect(calendar)} #{y} #{month}",
             fn ->
               {calendar.days_in_month(y, month), calendar.valid_date?(y, month, 30),
                answer(fn -> calendar.date_to_iso_days(y, month, 1) end)}
             end}
          end
      )
    end
  end

  @tag :full
  test "the astronomical Umm al-Qura months" do
    assert_same_from_kept_and_fresh(
      for y <- [1391, 1392, 1419, 1420, 1423, 1446, 1500], month <- [0, 1, 7, 12, 13] do
        {"#{y} #{month}",
         fn -> Calendrical.Islamic.UmmAlQura.Astronomical.first_day_of_month(y, month) end}
      end
    )
  end
end
