defmodule Calendrical.LocalizeExtendedYearTest do
  @moduledoc """
  Localize's `u` writes the extended year a date's calendar answers, its
  `extended_year/3`: TR35's "single number designating the year of this
  calendar system, encompassing all supra-year fields", in which the Julian
  calendar's 1 BCE is year 0. Localize cannot load Calendrical, so its `u`
  in Calendrical's calendars is held to ICU4C here.

  Each row is ICU4C 78.3's `SimpleDateFormat` text for the patterns `u` and
  `uuuu` on a day given as a proleptic Gregorian date, in a calendar ICU and
  Calendrical number alike. The Julian rows are ICU's Gregorian calendar
  with no change of rule (`setGregorianChange`).

  ICU writes the Gregorian year for the Buddhist and ROC calendars and the
  related Gregorian year for the Chinese and Dangi calendars. There the
  extended year is the calendar's own year (user, 2026-10-02), which
  Localize's ICU divergences guide records.

  """

  use ExUnit.Case, async: true

  # {calendar, proleptic Gregorian day, ICU4C's `u`, ICU4C's `uuuu`}
  @icu [
    {Calendrical.Gregorian, ~D[2026-06-15], "2026", "2026"},
    {Calendrical.Julian, ~D[2026-06-15], "2026", "2026"},
    {Calendrical.Julian, ~D[2026-01-10], "2025", "2025"},
    {Calendrical.Julian, ~D[0001-06-15], "1", "0001"},
    {Calendrical.Julian, ~D[0000-06-15], "0", "0000"},
    {Calendrical.Julian, ~D[-0001-06-15], "-1", "-0001"},
    {Calendrical.Julian, ~D[-0544-06-15], "-544", "-0544"},
    {Calendrical.Julian, ~D[-3760-10-01], "-3760", "-3760"},
    {Calendrical.Japanese, ~D[2026-06-15], "2026", "2026"},
    {Calendrical.Japanese, ~D[1912-01-01], "1912", "1912"},
    {Calendrical.Coptic, ~D[2026-06-15], "1742", "1742"},
    {Calendrical.Coptic, ~D[0284-08-29], "1", "0001"},
    {Calendrical.Coptic, ~D[0284-01-01], "0", "0000"},
    {Calendrical.Coptic, ~D[0008-08-27], "-275", "-0275"},
    {Calendrical.Coptic, ~D[0000-06-15], "-284", "-0284"},
    {Calendrical.Ethiopic, ~D[2026-06-15], "2018", "2018"},
    {Calendrical.Ethiopic, ~D[0008-08-27], "1", "0001"},
    {Calendrical.Ethiopic, ~D[0001-06-15], "-7", "-0007"},
    {Calendrical.Ethiopic.AmeteAlem, ~D[2026-06-15], "7518", "7518"},
    {Calendrical.Ethiopic.AmeteAlem, ~D[0008-08-27], "5501", "5501"},
    {Calendrical.Hebrew, ~D[2026-06-15], "5786", "5786"},
    {Calendrical.Hebrew, ~D[0000-06-15], "3760", "3760"},
    {Calendrical.Hebrew, ~D[-3760-10-01], "1", "0001"},
    {Calendrical.Indian, ~D[2026-06-15], "1948", "1948"},
    {Calendrical.Indian, ~D[0284-08-29], "206", "0206"},
    {Calendrical.Indian, ~D[0000-06-15], "-78", "-0078"},
    {Calendrical.Islamic.Civil, ~D[2026-06-15], "1447", "1447"},
    {Calendrical.Islamic.Civil, ~D[0622-07-19], "1", "0001"},
    {Calendrical.Islamic.Civil, ~D[0622-01-01], "0", "0000"},
    {Calendrical.Islamic.Civil, ~D[0284-08-29], "-348", "-0348"},
    {Calendrical.Islamic.Tbla, ~D[2026-06-15], "1447", "1447"},
    {Calendrical.Islamic.Tbla, ~D[0284-08-29], "-348", "-0348"},
    {Calendrical.Islamic.UmmAlQura, ~D[2026-06-15], "1447", "1447"},
    {Calendrical.Persian, ~D[2026-06-15], "1405", "1405"},
    {Calendrical.Persian, ~D[1912-01-01], "1290", "1290"}
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

  defp format(value, pattern),
    do: Localize.Date.to_string(value, format: pattern, locale: :en)

  describe "u" do
    test "is ICU4C's in the calendars both number alike" do
      for {calendar, iso, expected, padded} <- @icu do
        date = Date.convert!(iso, calendar)

        assert format(date, "u") == {:ok, expected}, "#{inspect(calendar)} on #{iso}"
        assert format(date, "uuuu") == {:ok, padded}, "#{inspect(calendar)} on #{iso}"
      end
    end

    # TR35: "with 1 BCE being year 0". The Julian calendars carry year -1
    # for 1 BC, so `u` and `y` part there.
    test "counts 1 BC as 0 in every Julian calendar, where the year is -1" do
      for calendar <- @julian do
        assert format(Date.new!(1, 6, 15, calendar), "u") == {:ok, "1"}, inspect(calendar)
        assert format(Date.new!(-1, 6, 15, calendar), "u") == {:ok, "0"}, inspect(calendar)
        assert format(Date.new!(-2, 6, 15, calendar), "u") == {:ok, "-1"}, inspect(calendar)
        assert format(Date.new!(-1, 6, 15, calendar), "y G") == {:ok, "1 BC"}, inspect(calendar)
      end
    end

    # ICU4C writes 2026 in all five on 15 June 2026: the Gregorian year in
    # the Buddhist and ROC calendars, and the related Gregorian year, the
    # `r` of the same date, in the Chinese, Dangi and Vietnamese.
    test "is the calendar's own year where ICU4C writes a Gregorian one" do
      for {calendar, expected} <- [
            {Calendrical.Buddhist, "2569"},
            {Calendrical.Roc, "115"},
            {Calendrical.Chinese, "4663"},
            {Calendrical.Korean, "4359"},
            {Calendrical.Vietnamese, "4663"}
          ] do
        date = Date.convert!(~D[2026-06-15], calendar)

        assert format(date, "u") == {:ok, expected}, inspect(calendar)
        assert format(date, "r") == {:ok, "2026"}, inspect(calendar)
      end
    end

    test "is a composite calendar's as the calendar in effect answers" do
      england = Date.convert!(~D[0000-06-15], Calendrical.Reform.England)

      assert england.year == -1
      assert format(england, "u") == {:ok, "0"}
      assert format(~D[1712-02-30 Calendrical.Reform.Sweden], "u") == {:ok, "1712"}
    end

    test "is a calendar of weeks' year" do
      assert format(~D[2026-W25-2 Calendrical.ISOWeek], "u") == {:ok, "2026"}
      assert format(Date.convert!(~D[2026-06-16], Calendrical.NRF), "u") == {:ok, "2026"}
    end
  end

  # A date without its month or day shows the extended year its days agree
  # on. A calendar built on the month or week base answers from the year
  # alone; any other is asked about the first and the last day the date
  # could be.
  describe "u of a partial date" do
    test "is the extended year of its year" do
      for {value, expected} <- [
            {%{year: 2026, calendar: Calendrical.Gregorian}, "2026"},
            {%{year: -1, calendar: Calendrical.Julian}, "0"},
            {%{year: -1, month: 6, calendar: Calendrical.Julian}, "0"},
            {%{year: -1, calendar: Calendrical.Julian.March25}, "0"},
            {%{year: -1, calendar: Calendrical.Reform.Sweden.Transitional}, "0"},
            {%{year: 5786, calendar: Calendrical.Hebrew}, "5786"},
            {%{year: 5786, month: 7, calendar: Calendrical.Hebrew}, "5786"},
            {%{year: 1447, calendar: Calendrical.Islamic.Civil}, "1447"},
            {%{year: 2026, calendar: Calendrical.Japanese}, "2026"},
            {%{year: 2019, calendar: Calendrical.Japanese}, "2019"},
            {%{year: 2026, calendar: Calendrical.ISOWeek}, "2026"},
            {%{year: 2026, month: 25, calendar: Calendrical.ISOWeek}, "2026"},
            {%{year: 2026, month: 53, calendar: Calendrical.ISOWeek}, "2026"}
          ] do
        assert format(value, "u") == {:ok, expected}, inspect(value)
      end
    end

    # December 1582 in Belgium has 21 days, the 1st to the 14th and the 25th
    # to the 31st, so the day its count names is none of them: the days asked
    # about are the first and the last the calendar has at or below it.
    test "is settled in a month a reform took days out of" do
      {:ok, belgium} = Calendrical.Reform.calendar_for(:BE)

      assert belgium.days_in_month(1582, 12) == 21
      refute belgium.valid_date?(1582, 12, 21)

      assert format(%{year: 1582, month: 12, calendar: belgium}, "u") == {:ok, "1582"}
      assert format(%{year: 1582, month: 12, calendar: belgium}, "y G") == {:ok, "1582 AD"}
    end
  end
end
