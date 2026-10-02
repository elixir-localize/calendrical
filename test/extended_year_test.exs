defmodule Calendrical.ExtendedYearTest do
  @moduledoc """
  The extended year, `extended_year/3`, is one number for a date's year
  that runs on through every era of its calendar: the year TR35's `u`
  format symbol writes. TR35 gives the Julian calendar as its example:
  "An extended year value for the Julian calendar system assigns positive
  values to CE years and negative values to BCE years, with 1 BCE being
  year 0."

  The expected values are ICU4C 78.3's `UCAL_EXTENDED_YEAR` for the same
  days, given here as proleptic Gregorian dates. Where ICU writes a
  Gregorian year for a calendar whose own years differ, the extended year
  is the calendar's own (user, 2026-10-02).

  """

  use ExUnit.Case, async: true

  # {calendar, proleptic Gregorian day, ICU4C 78.3's extended year}
  @icu [
    {Calendrical.Julian, ~D[2026-06-15], 2026},
    {Calendrical.Julian, ~D[1912-01-01], 1911},
    {Calendrical.Julian, ~D[0001-06-15], 1},
    {Calendrical.Julian, ~D[0000-06-15], 0},
    {Calendrical.Julian, ~D[-0001-06-15], -1},
    {Calendrical.Julian, ~D[-0544-06-15], -544},
    {Calendrical.Julian, ~D[-3760-10-01], -3760},
    {Calendrical.Gregorian, ~D[2026-06-15], 2026},
    {Calendrical.Gregorian, ~D[1912-01-01], 1912},
    {Calendrical.Japanese, ~D[2026-06-15], 2026},
    {Calendrical.Japanese, ~D[1912-01-01], 1912},
    {Calendrical.Coptic, ~D[2026-06-15], 1742},
    {Calendrical.Coptic, ~D[0284-08-29], 1},
    {Calendrical.Coptic, ~D[0008-08-27], -275},
    {Calendrical.Coptic, ~D[0000-06-15], -284},
    {Calendrical.Ethiopic, ~D[2026-06-15], 2018},
    {Calendrical.Ethiopic, ~D[0008-08-27], 1},
    {Calendrical.Ethiopic, ~D[0001-06-15], -7},
    {Calendrical.Ethiopic, ~D[-0544-06-15], -552},
    {Calendrical.Ethiopic.AmeteAlem, ~D[2026-06-15], 7518},
    {Calendrical.Ethiopic.AmeteAlem, ~D[0008-08-27], 5501},
    {Calendrical.Ethiopic.AmeteAlem, ~D[0000-06-15], 5492},
    {Calendrical.Ethiopic.AmeteAlem, ~D[-3760-10-01], 1733},
    {Calendrical.Hebrew, ~D[2026-06-15], 5786},
    {Calendrical.Hebrew, ~D[0284-08-29], 4044},
    {Calendrical.Hebrew, ~D[0000-06-15], 3760},
    {Calendrical.Hebrew, ~D[-3760-10-01], 1},
    {Calendrical.Indian, ~D[2026-06-15], 1948},
    {Calendrical.Indian, ~D[0284-08-29], 206},
    {Calendrical.Indian, ~D[0008-08-27], -70},
    {Calendrical.Indian, ~D[0000-06-15], -78},
    {Calendrical.Islamic.Civil, ~D[2026-06-15], 1447},
    {Calendrical.Islamic.Civil, ~D[0622-07-19], 1},
    {Calendrical.Islamic.Civil, ~D[0284-08-29], -348},
    {Calendrical.Islamic.Civil, ~D[0000-06-15], -641},
    {Calendrical.Islamic.Tbla, ~D[2026-06-15], 1447},
    {Calendrical.Islamic.Tbla, ~D[0622-07-19], 1},
    {Calendrical.Islamic.Tbla, ~D[0284-08-29], -348},
    {Calendrical.Islamic.UmmAlQura, ~D[2026-06-15], 1447},
    {Calendrical.Islamic.UmmAlQura, ~D[1912-01-01], 1330},
    {Calendrical.Persian, ~D[2026-06-15], 1405},
    {Calendrical.Persian, ~D[1912-01-01], 1290}
  ]

  @julian [
    Calendrical.Julian,
    Calendrical.Julian.Jan1,
    Calendrical.Julian.March1,
    Calendrical.Julian.March25,
    Calendrical.Julian.Sept1,
    Calendrical.Julian.Dec25,
    Calendrical.Reform.Sweden.Transitional
  ]

  describe "extended_year/3" do
    test "is ICU4C's extended year in the calendars both number alike" do
      for {calendar, iso, expected} <- @icu do
        date = Date.convert!(iso, calendar)

        assert calendar.extended_year(date.year, date.month, date.day) == expected,
               "#{inspect(calendar)} on #{iso}, #{inspect(date)}"

        assert Calendrical.extended_year(date) == expected
      end
    end

    # TR35: "1 BCE being year 0". The Julian calendar numbers its years -1
    # and 1 either side of the era, with no year 0.
    test "counts a Julian year BC from 0 down, where the year is counted from -1" do
      assert Calendrical.Julian.extended_year(1, 1, 1) == 1
      assert Calendrical.Julian.extended_year(-1, 12, 31) == 0
      assert Calendrical.Julian.extended_year(-2, 6, 15) == -1
      assert Calendrical.Julian.extended_year(-45, 3, 15) == -44
    end

    # A year reckoned from another day than 1 January keeps the Julian
    # calendar's years under its own labels, and so its count through 1 BC,
    # and Sweden's transitional calendar is the Julian calendar outside 1700
    # to 1712.
    test "counts a Julian new-year calendar's years the same way" do
      for calendar <- @julian do
        assert calendar.extended_year(2, 6, 15) == 2, inspect(calendar)
        assert calendar.extended_year(1, 6, 15) == 1, inspect(calendar)
        assert calendar.extended_year(-1, 6, 15) == 0, inspect(calendar)
        assert calendar.extended_year(-2, 6, 15) == -1, inspect(calendar)
      end
    end

    # A composite calendar answers as the calendar in effect on the date: the
    # Julian calendar in England before 1752.
    test "is the Julian calendar's in a composite calendar before its reform" do
      date = Date.convert!(~D[0000-06-15], Calendrical.Reform.England)

      assert date.year == -1
      assert Calendrical.Reform.England.extended_year(date.year, date.month, date.day) == 0
    end

    # ICU4C writes the Gregorian year for the Buddhist and ROC calendars
    # (2026) and the related Gregorian year for the Chinese and Dangi
    # calendars (2026). TR35 calls the extended year "the year of this
    # calendar system" and gives 4601 as its example, a Chinese year counted
    # on from 2637 BC, so it is the calendar's own year here.
    test "is the calendar's own year where ICU4C writes a Gregorian one" do
      for {calendar, year} <- [
            {Calendrical.Buddhist, 2569},
            {Calendrical.Roc, 115},
            {Calendrical.Chinese, 4663},
            {Calendrical.Korean, 4359},
            {Calendrical.Vietnamese, 4663}
          ] do
        date = Date.convert!(~D[2026-06-15], calendar)

        assert date.year == year, inspect(calendar)
        assert calendar.extended_year(date.year, date.month, date.day) == year, inspect(calendar)
      end
    end
  end

  # One number through every era has no gap and no repeat: from one day to
  # the next it is the same, or one more where the year turns. The spans
  # cross 1 BC, where the Julian calendars skip from -1 to 1, the first
  # years of the Coptic, Ethiopic, Islamic, Indian, Buddhist and ROC
  # counts, and the present.
  describe "the extended year runs on" do
    @spans [
      {~D[-0003-01-01], ~D[0003-12-31]},
      {~D[-0546-01-01], ~D[-0541-12-31]},
      {~D[0006-01-01], ~D[0010-12-31]},
      {~D[0076-01-01], ~D[0080-12-31]},
      {~D[0282-01-01], ~D[0286-12-31]},
      {~D[0620-01-01], ~D[0624-12-31]},
      {~D[1909-06-01], ~D[1913-06-01]},
      {~D[2024-01-01], ~D[2027-12-31]}
    ]

    @calendars [
      Calendrical.Gregorian,
      Calendrical.ISOWeek,
      Calendrical.NRF,
      Calendrical.Buddhist,
      Calendrical.Roc,
      Calendrical.Japanese,
      Calendrical.Coptic,
      Calendrical.Ethiopic,
      Calendrical.Ethiopic.AmeteAlem,
      Calendrical.Hebrew,
      Calendrical.Indian,
      Calendrical.Islamic.Civil,
      Calendrical.Islamic.Tbla,
      Calendrical.Reform.England,
      Calendrical.Reform.Sweden
    ]

    test "by one at each new year, in every calendar" do
      for calendar <- @calendars ++ @julian, {first, last} <- @spans do
        Date.range(first, last)
        |> Enum.map(&Date.convert!(&1, calendar))
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.each(fn [day, next] ->
          step =
            calendar.extended_year(next.year, next.month, next.day) -
              calendar.extended_year(day.year, day.month, day.day)

          assert step == if(day.year == next.year, do: 0, else: 1),
                 "#{inspect(day)} then #{inspect(next)}"
        end)
      end
    end
  end
end
