defmodule Calendrical.TraditionalMonthsTest do
  @moduledoc """
  The traditional months of a year, which every calendar answers:
  `traditional_months/1`, `lunar_month_of_year/2`,
  `ordinal_month_from_traditional/2`, `leap_month/1` and
  `traditional_leap_month/1`.

  The four that turn a month's place into its name and back were callbacks
  only the lunisolar calendars had, so a caller asked a calendar whether it
  exported them, and `Calendrical.traditional_months/2` did so for it. Every
  calendar answers now: a lunisolar one with its own months, and any other
  with its months as their own numbering and no leap month.

  The leap months are known apart from the library. The Hebrew year 5784
  has Adar I after its fifth month, Shevat, and 5785 has none. The Chinese
  year 4660, which began in January 2023, has a leap second month. A year's
  list is also held to what each place of the year answers for itself, which
  is the calendar's own count of that month and no list.

  """

  use ExUnit.Case, async: true

  @lunisolar [
    {Calendrical.Hebrew, 5780..5800},
    {Calendrical.Chinese, 4655..4665},
    {Calendrical.Korean, 4350..4360},
    {Calendrical.Vietnamese, 4655..4665},
    {Calendrical.LunarJapanese, 2660..2670}
  ]

  describe "traditional_months/1 of a lunisolar calendar" do
    test "has the leap month after the month it follows" do
      assert Calendrical.Hebrew.traditional_months(5784) ==
               [1, 2, 3, 4, 5, {5, :leap}, 6, 7, 8, 9, 10, 11, 12]

      assert Calendrical.Hebrew.traditional_months(5785) == Enum.to_list(1..12)

      assert Calendrical.Chinese.traditional_months(4660) ==
               [1, 2, {2, :leap}, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    end

    test "names each place of the year as the place names itself" do
      for {calendar, years} <- @lunisolar, year <- years do
        months = calendar.traditional_months(year)

        assert length(months) == calendar.months_in_year(year), "#{inspect(calendar)} #{year}"

        for {name, place} <- Enum.with_index(months, 1) do
          assert calendar.lunar_month_of_year(year, place) == name,
                 "#{inspect(calendar)} #{year} month #{place}"

          assert calendar.ordinal_month_from_traditional(year, name) == {:ok, place},
                 "#{inspect(calendar)} #{year} #{inspect(name)}"
        end
      end
    end

    test "has its leap month where leap_month/1 and traditional_leap_month/1 say" do
      for {calendar, years} <- @lunisolar, year <- years do
        months = calendar.traditional_months(year)

        case Enum.find_index(months, &match?({_follows, :leap}, &1)) do
          nil ->
            assert calendar.leap_month(year) == nil
            assert calendar.traditional_leap_month(year) == nil

          index ->
            {follows, :leap} = Enum.at(months, index)
            assert calendar.leap_month(year) == index + 1
            assert calendar.traditional_leap_month(year) == follows
        end
      end
    end
  end

  describe "a calendar whose months are their own numbering" do
    test "lists the months of a year by their numbers" do
      assert Calendrical.Gregorian.traditional_months(2026) == Enum.to_list(1..12)
      assert Calendrical.Coptic.traditional_months(1742) == Enum.to_list(1..13)
      assert Calendrical.Julian.traditional_months(1750) == Enum.to_list(1..12)
      assert Calendrical.Julian.March25.traditional_months(1750) == Enum.to_list(1..13)
      assert Calendrical.ISOWeek.traditional_months(2026) == Enum.to_list(1..12)
      assert Calendrical.Reform.England.traditional_months(1760) == Enum.to_list(1..12)
    end

    test "names a month by its place, and places a month by its name" do
      for {calendar, year, months} <- [
            {Calendrical.Gregorian, 2026, 12},
            {Calendrical.Coptic, 1742, 13},
            {Calendrical.Persian, 1405, 12},
            {Calendrical.Julian.March25, 1750, 13}
          ] do
        for month <- 1..months do
          assert calendar.lunar_month_of_year(year, month) == month
          assert calendar.ordinal_month_from_traditional(year, month) == {:ok, month}
        end

        assert calendar.lunar_month_of_year(year, months + 1) == {:error, :invalid_month}

        assert calendar.ordinal_month_from_traditional(year, months + 1) ==
                 {:error, :invalid_month}

        assert calendar.lunar_month_of_year(year, 0) == {:error, :invalid_month}
        assert calendar.ordinal_month_from_traditional(year, 0) == {:error, :invalid_month}
      end
    end

    test "has no leap month" do
      for calendar <- [Calendrical.Gregorian, Calendrical.Coptic, Calendrical.Islamic.Civil] do
        assert calendar.leap_month(2026) == nil
        assert calendar.traditional_leap_month(2026) == nil

        assert calendar.ordinal_month_from_traditional(2026, {5, :leap}) ==
                 {:error, :invalid_leap_month}
      end
    end

    test "answers what is no year or no month with an error, and never raises" do
      calendar = Calendrical.Gregorian

      assert calendar.lunar_month_of_year(nil, 1) == {:error, :invalid_month}
      assert calendar.lunar_month_of_year(2026, "1") == {:error, :invalid_month}
      assert calendar.ordinal_month_from_traditional(nil, 1) == {:error, :invalid_month}
      assert calendar.ordinal_month_from_traditional(2026, :january) == {:error, :invalid_month}
      assert calendar.traditional_months(nil) == []
    end
  end

  describe "a year its calendar does not have" do
    test "has no months" do
      # England's composite has no year 0.
      assert Calendrical.Reform.England.months_in_year(0) == 0
      assert Calendrical.Reform.England.traditional_months(0) == []
    end
  end

  describe "Calendrical.traditional_months/2" do
    test "is the calendar's own answer, and the Gregorian calendar's for Calendar.ISO" do
      assert Calendrical.traditional_months(5784, Calendrical.Hebrew) ==
               Calendrical.Hebrew.traditional_months(5784)

      assert Calendrical.traditional_months(2026, Calendar.ISO) == Enum.to_list(1..12)
    end
  end
end
