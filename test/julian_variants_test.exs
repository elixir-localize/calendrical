defmodule Calendrical.JulianVariantsTest do
  @moduledoc """
  Tests for the Julian year-shift variants (`March1`, `March25`,
  `Sept1`, `Dec25`).

  Each variant numbers the Julian year from a historical new-year day.
  A year reckoned from 1 March or 25 March takes the number of the
  Julian year it begins in, and one reckoned from 1 September or 25
  December the number of the Julian year it ends in, as the styles were
  used.

  The expected years are those of C. R. Cheney's *A Handbook of Dates*
  (new edition, Cambridge, 2000), chapter 1, section IV, "The beginning
  of the year of grace". Its figure 2 sets the years 1099 to 1101 of the
  Nativity and of the two Annunciation reckonings against the modern
  ones, and it gives Matthew Paris's 26 December 1250, in the Christmas
  reckoning, as 26 December 1249. A Byzantine year of the world is 5509
  more than the Julian year from September to December and 5508 more
  from January to August.

  """

  use ExUnit.Case, async: true

  doctest Calendrical.Julian.March1
  doctest Calendrical.Julian.March25
  doctest Calendrical.Julian.Sept1
  doctest Calendrical.Julian.Dec25

  alias Calendrical.Julian.{Dec25, March1, March25, Sept1}

  # The Pisan reckoning of the Annunciation style: the year begins on the
  # 25 March before 1 January of the same number.
  defmodule Pisan do
    @moduledoc false
    use Calendrical.Julian, new_year_starting_month_and_day: {3, 25}, year: :ending
  end

  # Years numbered by the Julian year most of them fall in: the one a year
  # that begins in June begins in, and the one a year that begins in July
  # ends in.
  defmodule MajorityFromJune do
    @moduledoc false
    use Calendrical.Julian, new_year_starting_month_and_day: {6, 24}, year: :majority
  end

  defmodule MajorityFromJuly do
    @moduledoc false
    use Calendrical.Julian, new_year_starting_month_and_day: {7, 1}, year: :majority
  end

  # No `:year`: the Julian year the year begins in.
  defmodule FromOctober do
    @moduledoc false
    use Calendrical.Julian, new_year_starting_month_and_day: {10, 1}
  end

  # A year that begins on 1 January begins and ends in the same year.
  defmodule JanuaryEnding do
    @moduledoc false
    use Calendrical.Julian, new_year_starting_month_and_day: {1, 1}, year: :ending
  end

  @variants [
    Calendrical.Julian.March1,
    Calendrical.Julian.March25,
    Calendrical.Julian.Sept1,
    Calendrical.Julian.Dec25
  ]

  # Each calendar with its new-year day and the Julian year that numbers
  # its year.
  @reckonings [
    {March1, {3, 1}, :beginning},
    {March25, {3, 25}, :beginning},
    {Sept1, {9, 1}, :ending},
    {Dec25, {12, 25}, :ending},
    {Pisan, {3, 25}, :ending},
    {MajorityFromJune, {6, 24}, :beginning},
    {MajorityFromJuly, {7, 1}, :ending},
    {FromOctober, {10, 1}, :beginning},
    {JanuaryEnding, {1, 1}, :beginning}
  ]

  # The Julian calendar is 13 days behind the Gregorian from 1900 to 2100.
  describe "the day the year changes" do
    test "March1: on Julian 1 March, after 1 January of the same number" do
      assert Date.convert(~D[2024-03-13], March1) ==
               {:ok, ~D[2023-02-29 Calendrical.Julian.March1]}

      assert Date.convert(~D[2024-03-14], March1) ==
               {:ok, ~D[2024-03-01 Calendrical.Julian.March1]}
    end

    test "March25: on Julian 25 March, after 1 January of the same number" do
      assert Date.convert(~D[2024-04-06], March25) ==
               {:ok, ~D[2023-03-24 Calendrical.Julian.March25]}

      assert Date.convert(~D[2024-04-07], March25) ==
               {:ok, ~D[2024-03-25 Calendrical.Julian.March25]}
    end

    test "Sept1: on Julian 1 September, before 1 January of the same number" do
      assert Date.convert(~D[2024-09-13], Sept1) == {:ok, ~D[2024-08-31 Calendrical.Julian.Sept1]}
      assert Date.convert(~D[2024-09-14], Sept1) == {:ok, ~D[2025-09-01 Calendrical.Julian.Sept1]}
      assert Date.convert(~D[2025-01-14], Sept1) == {:ok, ~D[2025-01-01 Calendrical.Julian.Sept1]}
    end

    test "Dec25: on Julian 25 December, before 1 January of the same number" do
      assert Date.convert(~D[2025-01-06], Dec25) == {:ok, ~D[2024-12-24 Calendrical.Julian.Dec25]}
      assert Date.convert(~D[2025-01-07], Dec25) == {:ok, ~D[2025-12-25 Calendrical.Julian.Dec25]}
      assert Date.convert(~D[2025-01-14], Dec25) == {:ok, ~D[2025-01-01 Calendrical.Julian.Dec25]}
    end
  end

  describe "the number of a year, as each style was used" do
    # Cheney, figure 2, "Calendars for 1099-1101": the Nativity year 1100
    # begins on 25 December of the modern year 1099, and 1101 on 25 December
    # 1100; the conventional Annunciation year 1100 begins on 25 March 1100,
    # and 1101 on 25 March 1101; the Pisan Annunciation year 1101 begins on
    # 25 March 1100, and 1102 on 25 March 1101.
    test "Cheney's calendars for 1099 to 1101" do
      for {calendar, year, {julian_year, month, day}} <- [
            {Dec25, 1100, {1099, 12, 25}},
            {Dec25, 1101, {1100, 12, 25}},
            {March25, 1100, {1100, 3, 25}},
            {March25, 1101, {1101, 3, 25}},
            {Pisan, 1101, {1100, 3, 25}},
            {Pisan, 1102, {1101, 3, 25}}
          ] do
        first_day = Date.new!(julian_year, month, day, Calendrical.Julian)
        day_before = Date.add(first_day, -1)

        assert %Date{year: ^year, month: ^month, day: ^day} = Date.convert!(first_day, calendar)
        assert Date.convert!(day_before, calendar).year == year - 1
        assert calendar.year(year).first == Date.convert!(first_day, calendar)
        assert calendar.year(year - 1).last == Date.convert!(day_before, calendar)
      end
    end

    # Cheney: Edmund of Cornwall "is very commonly said - on the authority
    # of Matthew Paris - to have been born on 26 December 1250. But Matthew
    # Paris used the Christmas reckoning, and the historical date is
    # therefore 26 December 1249."
    test "Matthew Paris's 26 December 1250 is 26 December 1249" do
      assert Date.convert!(~D[1250-12-26 Calendrical.Julian.Dec25], Calendrical.Julian) ==
               ~D[1249-12-26 Calendrical.Julian]

      assert Date.convert!(~D[1250-12-24 Calendrical.Julian.Dec25], Calendrical.Julian) ==
               ~D[1250-12-24 Calendrical.Julian]
    end

    # The year of the world 7208 began on 1 September 1699 and ended on 31
    # August 1700, and 6961 held 29 May 1453: each is the September year
    # and 5508.
    test "a Byzantine year of the world is the September year and 5508" do
      for {julian, year_of_the_world} <- [
            {~D[1699-08-31 Calendrical.Julian], 7207},
            {~D[1699-09-01 Calendrical.Julian], 7208},
            {~D[1699-12-31 Calendrical.Julian], 7208},
            {~D[1700-01-01 Calendrical.Julian], 7208},
            {~D[1700-08-31 Calendrical.Julian], 7208},
            {~D[1700-09-01 Calendrical.Julian], 7209},
            {~D[1453-05-29 Calendrical.Julian], 6961}
          ] do
        assert julian.year + if(julian.month >= 9, do: 5509, else: 5508) == year_of_the_world
        assert Date.convert!(julian, Sept1).year + 5508 == year_of_the_world, inspect(julian)
      end
    end

    # In the Venetian style January and February are of the year before.
    test "January and February of a year reckoned from 1 March are of the year before" do
      assert Date.convert!(~D[1700-01-01 Calendrical.Julian], March1) ==
               ~D[1699-01-01 Calendrical.Julian.March1]

      assert Date.convert!(~D[1700-02-29 Calendrical.Julian], March1) ==
               ~D[1699-02-29 Calendrical.Julian.March1]

      assert Date.convert!(~D[1700-03-01 Calendrical.Julian], March1) ==
               ~D[1700-03-01 Calendrical.Julian.March1]
    end
  end

  # A year's number is its Julian year's, but for the part of the year that
  # lies in the other Julian year: the days before the new-year day are of
  # the year before, where a year takes the number of the Julian year it
  # begins in, and the days from the new-year day on are of the year after,
  # where it takes the number of the Julian year it ends in. The Julian
  # calendar has no year 0.
  defp numbered({julian_year, month, day}, new_year, :beginning) when {month, day} < new_year,
    do: if(julian_year == 1, do: -1, else: julian_year - 1)

  defp numbered({julian_year, month, day}, new_year, :ending) when {month, day} >= new_year,
    do: if(julian_year == -1, do: 1, else: julian_year + 1)

  defp numbered({julian_year, _month, _day}, _new_year, _numbering), do: julian_year

  describe "the `:year` option" do
    test "numbers every day of 3 BC to AD 3 and of 1099 to 1101 by its reckoning" do
      for {calendar, new_year, numbering} <- @reckonings,
          range <- [
            Date.range(~D[-0003-01-01], ~D[0003-12-31]),
            Date.range(~D[1099-01-01], ~D[1101-12-31])
          ],
          iso <- range do
        %{year: year, month: month, day: day} = Date.convert!(iso, Calendrical.Julian)
        date = Date.convert!(iso, calendar)

        assert {date.year, date.month, date.day} ==
                 {numbered({year, month, day}, new_year, numbering), month, day},
               "#{inspect(calendar)} on #{iso}"

        assert calendar.valid_date?(date.year, date.month, date.day)
        assert Date.convert!(date, Calendar.ISO) == iso
      end
    end

    test "`:majority` is the Julian year a year begins in when it begins in January to June" do
      assert Date.convert!(~D[1100-06-24 Calendrical.Julian], MajorityFromJune).year == 1100
      assert Date.convert!(~D[1100-06-23 Calendrical.Julian], MajorityFromJune).year == 1099
      assert Date.convert!(~D[1100-07-01 Calendrical.Julian], MajorityFromJuly).year == 1101
      assert Date.convert!(~D[1100-06-30 Calendrical.Julian], MajorityFromJuly).year == 1100
    end

    test "without it a year takes the number of the Julian year it begins in" do
      assert Date.convert!(~D[1100-10-01 Calendrical.Julian], FromOctober).year == 1100
      assert Date.convert!(~D[1100-09-30 Calendrical.Julian], FromOctober).year == 1099
    end

    test "a year that begins on 1 January is the Julian year either way" do
      for iso <- Date.range(~D[-0002-12-01], ~D[0002-02-28]) do
        julian = Date.convert!(iso, Calendrical.Julian)
        date = Date.convert!(iso, JanuaryEnding)

        assert {date.year, date.month, date.day} == {julian.year, julian.month, julian.day}
      end
    end

    test "any other value does not compile" do
      assert_raise ArgumentError,
                   ":year must be either :beginning, :ending or :majority. Found :first.",
                   fn ->
                     defmodule Unknown do
                       use Calendrical.Julian,
                         new_year_starting_month_and_day: {3, 1},
                         year: :first
                     end
                   end
    end
  end

  # The Julian calendar has no year 0, whichever day its year begins on,
  # and answers as `Calendrical.Julian` does for one.
  describe "no year is numbered 0" do
    test "in a calendar reckoned from any day" do
      calendars = [Calendrical.Julian.Jan1 | Enum.map(@reckonings, &elem(&1, 0))]

      for calendar <- [Calendrical.Julian | calendars] do
        for month <- 1..12, day <- 1..31 do
          refute calendar.valid_date?(0, month, day), "#{inspect(calendar)} 0-#{month}-#{day}"
        end

        assert Date.new(0, 6, 15, calendar) == {:error, :invalid_date}, inspect(calendar)
        assert calendar.year(0) == {:error, :invalid_date}, inspect(calendar)
        assert calendar.month(0, 1) == {:error, :invalid_date}, inspect(calendar)
        assert calendar.month(0, 12) == {:error, :invalid_date}, inspect(calendar)
        assert calendar.quarter(0, 1) == {:error, :invalid_date}, inspect(calendar)
        assert calendar.quadrimester(0, 3) == {:error, :invalid_date}, inspect(calendar)
        assert calendar.semester(0, 2) == {:error, :invalid_date}, inspect(calendar)
      end
    end

    test "and the day after the last of 1 BC is the first of AD 1" do
      for {calendar, {month, day}, _numbering} <- @reckonings do
        first_day = Date.new!(1, month, day, calendar)
        last_day = Date.add(first_day, -1)

        assert last_day.year == -1, inspect(calendar)
        assert calendar.year(1).first == first_day
        assert calendar.year(-1).last == last_day
        assert Date.day_of_era(first_day) == {1, 1}
        assert Date.day_of_era(last_day) == {1, 0}
      end
    end
  end

  describe "round-trips" do
    test "every variant round-trips through a full year of dates" do
      for variant <- @variants,
          day_offset <- 0..366 do
        date = Date.add(~D[2023-06-15], day_offset)
        {:ok, in_variant} = Date.convert(date, variant)
        assert {:ok, ^date} = Date.convert(in_variant, Calendar.ISO)
      end
    end

    test "variant dates agree with plain Julian on month and day" do
      for variant <- @variants, day_offset <- 0..30 do
        date = Date.add(~D[2024-06-01], day_offset)
        {:ok, julian} = Date.convert(date, Calendrical.Julian)
        {:ok, in_variant} = Date.convert(date, variant)

        assert {julian.month, julian.day} == {in_variant.month, in_variant.day}
      end
    end
  end

  # Each day of two years, as a plain Julian date and a variant date.
  defp day_pairs(variant) do
    for day_offset <- 0..730 do
      iso = Date.add(~D[2023-01-01], day_offset)
      {Date.convert!(iso, Calendrical.Julian), Date.convert!(iso, variant)}
    end
  end

  describe "month lengths follow the date's own Julian month" do
    test "days_in_month/2 agrees with valid_date?/3 for every month of every year" do
      for variant <- [Calendrical.Julian.Jan1 | @variants],
          year <- 2020..2027,
          month <- 1..12,
          day <- 1..31 do
        assert variant.valid_date?(year, month, day) == day <= variant.days_in_month(year, month),
               "#{inspect(variant)} #{year}-#{month}-#{day}"
      end
    end

    test "Date.days_in_month/1 matches plain Julian" do
      for variant <- @variants, {julian, in_variant} <- day_pairs(variant) do
        assert Date.days_in_month(in_variant) == Date.days_in_month(julian)
      end
    end

    test "a March1 February follows the leap year of its Julian year" do
      # March1 label 2023 runs 1 March 2023 to 29 February 2024 (Julian).
      assert Calendrical.Julian.March1.days_in_month(2023, 2) == 29
      assert Calendrical.Julian.March1.days_in_month(2024, 2) == 28
      assert Calendrical.Julian.Sept1.days_in_month(2024, 9) == 30
    end

    # A year reckoned from 1 September or 25 December holds the February of
    # the Julian year it ends in, and 2024 is a Julian leap year.
    test "a Sept1 or Dec25 February is that of the Julian year the year ends in" do
      for calendar <- [Sept1, Dec25] do
        assert calendar.days_in_month(2024, 2) == 29, inspect(calendar)
        assert calendar.days_in_month(2023, 2) == 28, inspect(calendar)
        assert calendar.days_in_month(2025, 2) == 28, inspect(calendar)
        assert calendar.valid_date?(2024, 2, 29), inspect(calendar)
        refute calendar.valid_date?(2023, 2, 29), inspect(calendar)
        assert calendar.leap_year?(2024), inspect(calendar)
        refute calendar.leap_year?(2023), inspect(calendar)

        assert {calendar.days_in_year(2023), calendar.days_in_year(2024)} == {365, 366},
               inspect(calendar)
      end

      # December of a year reckoned from 25 December is the last week of one
      # Julian December and the first 24 days of the next.
      assert Dec25.days_in_month(2024, 12) == 31

      assert Date.diff(
               ~D[2024-12-24 Calendrical.Julian.Dec25],
               ~D[2024-12-25 Calendrical.Julian.Dec25]
             ) == 365
    end

    test "days_in_month/1 is the Julian month's length" do
      assert Calendrical.Julian.March25.days_in_month(1) == 31
      assert Calendrical.Julian.March25.days_in_month(2) == {:ambiguous, 28..29}
      assert Calendrical.Julian.March25.days_in_month(13) == {:error, :undefined}
      assert Calendrical.Julian.March25.months_in_year() == 12
    end
  end

  describe "arithmetic follows the Julian date" do
    test "Date.shift/2 lands on the same day as in plain Julian" do
      durations =
        [month: -13, month: -1, month: 1, month: 11, month: 13, year: -1, year: 1] ++
          [week: 1, week: -3, day: 1, day: -400]

      for variant <- [Calendrical.Julian.Jan1 | @variants],
          {julian, in_variant} <- day_pairs(variant),
          {unit, n} <- durations do
        duration = Duration.new!([{unit, n}])

        assert Date.convert!(Date.shift(in_variant, duration), Calendar.ISO) ==
                 Date.convert!(Date.shift(julian, duration), Calendar.ISO),
               "#{inspect(in_variant)} + #{unit} #{n}"
      end
    end

    test "years and months together land on the same day as in plain Julian" do
      durations = [
        [year: 1, month: 1],
        [year: -1, month: 13],
        [year: 2, month: -1],
        [year: 1, month: -12]
      ]

      for variant <- [Calendrical.Julian.Jan1 | @variants],
          {julian, in_variant} <- day_pairs(variant),
          duration <- durations do
        assert Date.convert!(Date.shift(in_variant, duration), Calendar.ISO) ==
                 Date.convert!(Date.shift(julian, duration), Calendar.ISO),
               "#{inspect(in_variant)} + #{inspect(duration)}"
      end
    end

    test "plain Julian shifts by weeks" do
      assert Date.shift(~D[2025-01-01 Calendrical.Julian], week: 1) ==
               ~D[2025-01-08 Calendrical.Julian]

      assert Calendrical.Julian.plus(2025, 1, 1, :weeks, 2) == {2025, 1, 15}
    end
  end

  describe "year-relative months, years and times" do
    test "month/2 tiles the year from its first day to its last" do
      for variant <- [Calendrical.Julian.Jan1 | @variants], year <- [2023, 2024] do
        ranges = for month <- 1..12, do: variant.month(year, month)
        first = Date.to_gregorian_days(Enum.at(ranges, 0).first)
        last = Date.to_gregorian_days(List.last(ranges).last)

        assert first == variant.first_iso_day_of_year(year)
        assert last == variant.last_iso_day_of_year(year)

        ranges
        |> Enum.zip(tl(ranges))
        |> Enum.each(fn {range, next} ->
          assert Date.to_gregorian_days(range.last) + 1 == Date.to_gregorian_days(next.first)
        end)

        # A date's month of the year is its Julian month, which names it
        for range <- ranges, date <- [range.first, range.last] do
          assert Calendrical.month_of_year(date) == date.month
        end
      end
    end

    test "extended_year/3 and related_gregorian_year/3 hold for every date of the year" do
      for variant <- @variants, {_julian, date} <- day_pairs(variant) do
        assert variant.extended_year(date.year, date.month, date.day) == date.year

        {:ok, first} =
          Date.new(
            date.year,
            variant.first_day_of_year(date.year) |> elem(1),
            variant.first_day_of_year(date.year) |> elem(2),
            variant
          )

        assert variant.related_gregorian_year(date.year, date.month, date.day) ==
                 Date.convert!(first, Calendar.ISO).year
      end
    end

    test "a naive datetime keeps its time of day" do
      for variant <- @variants do
        {:ok, naive} = NaiveDateTime.new(2024, 6, 1, 10, 30, 15, {0, 0}, variant)
        {:ok, iso} = NaiveDateTime.convert(naive, Calendar.ISO)
        assert {iso.hour, iso.minute, iso.second} == {10, 30, 15}
        assert {:ok, ^naive} = NaiveDateTime.convert(iso, variant)
      end
    end
  end

  # The year label names the era: under the Annunciation style the days
  # up to 24 March AD 1 were still 1 BC, and under the Nativity style
  # 25 December 1 BC was already AD 1.
  describe "the era of a label year" do
    test "the new-year day begins the era" do
      assert Calendrical.Julian.March25.year_of_era(-1, 3, 24) == {1, 0}
      assert Calendrical.Julian.March25.year_of_era(1, 3, 25) == {1, 1}
      assert Calendrical.Julian.Dec25.year_of_era(-1, 12, 24) == {1, 0}
      assert Calendrical.Julian.Dec25.year_of_era(1, 12, 25) == {1, 1}

      assert Calendrical.Julian.March25.day_of_era(-1, 3, 24) == {1, 0}
      assert Calendrical.Julian.March25.day_of_era(1, 3, 25) == {1, 1}

      assert Date.convert!(~D[0001-03-24 Calendrical.Julian], March25) ==
               ~D[-0001-03-24 Calendrical.Julian.March25]

      assert Date.convert!(~D[-0001-12-25 Calendrical.Julian], Dec25) ==
               ~D[0001-12-25 Calendrical.Julian.Dec25]

      assert Calendrical.Julian.Dec25.day_of_era(-1, 12, 24) == {1, 0}
      assert Calendrical.Julian.Dec25.day_of_era(1, 12, 25) == {1, 1}
    end

    test "the year of era is the calendar year, and the day of era agrees" do
      for variant <- @variants, iso <- Date.range(~D[-0002-12-01], ~D[0002-04-30]) do
        %{year: year, month: month, day: day} = Date.convert!(iso, variant)
        {year_of_era, era} = variant.year_of_era(year, month, day)
        calendar_year = variant.calendar_year(year, month, day)

        assert calendar_year == if(era == 1, do: year_of_era, else: -year_of_era),
               "#{inspect(variant)} #{iso}"

        assert {_day, ^era} = variant.day_of_era(year, month, day)
      end
    end
  end

  # A variant's date keeps its Julian month and day under the label of the
  # year its day falls in, so its fields are not in the order of its days: 1
  # January follows 31 December of the same label year. `Date.compare/2`
  # orders two dates of one calendar by their fields and never asks the
  # calendar, so dates are ordered by their days (`Date.diff/2`). The ranges
  # below cross January and each variant's new-year day; the days expected
  # are the ISO days between the two, in the variant.
  describe "dates are ordered by their days, not their fields" do
    @ranges [
      {~D[2023-01-01], ~D[2023-01-28]},
      {~D[2023-12-20], ~D[2024-01-20]},
      {~D[2024-03-01], ~D[2024-04-15]},
      {~D[2024-08-25], ~D[2024-09-20]}
    ]

    test "the year's last day in December is the day before 1 January of the same year" do
      december = Date.new!(2022, 12, 31, Calendrical.Julian.March25)
      january = Date.new!(2022, 1, 1, Calendrical.Julian.March25)

      assert Date.diff(january, december) == 1
      assert Calendrical.interval(december, january, :days) == [december, january]
      assert Calendrical.interval(january, december, :days) == [january, december]
    end

    test "interval/3 runs from the earlier day to the later, and back" do
      for variant <- @variants, {from_iso, to_iso} <- @ranges do
        from = Date.convert!(from_iso, variant)
        to = Date.convert!(to_iso, variant)
        days = for iso <- Date.range(from_iso, to_iso), do: Date.convert!(iso, variant)

        assert Calendrical.interval(from, to, :days) == days,
               "#{inspect(from)} to #{inspect(to)}"

        assert Calendrical.interval(to, from, :days) == Enum.reverse(days),
               "#{inspect(to)} to #{inspect(from)}"
      end
    end

    test "interval_stream/3 runs from the earlier day to the later, and back" do
      for variant <- @variants, {from_iso, to_iso} <- @ranges do
        from = Date.convert!(from_iso, variant)
        to = Date.convert!(to_iso, variant)
        days = for iso <- Date.range(from_iso, to_iso), do: Date.convert!(iso, variant)

        assert Enum.to_list(Calendrical.interval_stream(from, to, :days)) == days,
               "#{inspect(from)} to #{inspect(to)}"

        assert Enum.to_list(Calendrical.interval_stream(to, from, :days)) == Enum.reverse(days),
               "#{inspect(to)} to #{inspect(from)}"
      end
    end

    test "an interval of months is the plain Julian calendar's, relabelled" do
      plain =
        Calendrical.interval(
          Date.convert!(~D[2023-10-10], Calendrical.Julian),
          Date.convert!(~D[2024-05-10], Calendrical.Julian),
          :months
        )

      assert length(plain) == 8

      for variant <- @variants do
        from = Date.convert!(~D[2023-10-10], variant)
        to = Date.convert!(~D[2024-05-10], variant)

        assert Calendrical.interval(from, to, :months) ==
                 Enum.map(plain, &Date.convert!(&1, variant)),
               inspect(variant)
      end
    end
  end
end
