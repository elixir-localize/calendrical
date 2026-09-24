defmodule Calendrical.LunisolarValidation.Test do
  use ExUnit.Case, async: true

  @lunisolar [
    Calendrical.Chinese,
    Calendrical.Korean,
    Calendrical.Vietnamese,
    Calendrical.LunarJapanese
  ]

  # Calendars whose `valid_date?/3` comes from `Calendrical.Behaviour`, or from
  # a component calendar whose does.
  @behaviour_calendars [
    Calendrical.Persian,
    Calendrical.Japanese,
    Calendrical.Islamic.Civil,
    Calendrical.Islamic.Tbla,
    Calendrical.Reform.Japan,
    Calendrical.Reform.Sweden.Transitional
  ]

  # The years of each lunisolar calendar that contain these Gregorian dates.
  defp years(calendar, gregorian_dates) do
    gregorian_dates
    |> Enum.map(fn date -> date |> Date.convert!(calendar) |> Map.fetch!(:year) end)
    |> Enum.uniq()
  end

  defp sample_years(calendar) do
    years(
      calendar,
      for(year <- [1849..1856, 2020..2027, 2220..2227], y <- year, do: Date.new!(y, 7, 1))
    )
  end

  describe "valid_date?/3 and Date.new/4 reject a month or day below 1" do
    for calendar <- @lunisolar ++ @behaviour_calendars do
      test "#{inspect(calendar)}" do
        calendar = unquote(calendar)
        %{year: year} = Date.convert!(~D[2025-06-15], calendar)
        assert calendar.valid_date?(year, 1, 1)

        for {month, day} <- [{0, 1}, {1, 0}, {-1, 1}, {1, -1}, {0, 0}] do
          refute calendar.valid_date?(year, month, day)
          assert {:error, :invalid_date} = Date.new(year, month, day, calendar)
        end
      end
    end

    test "a non-integer part is not a valid date" do
      refute Calendrical.Chinese.valid_date?(4662, "1", 1)
      refute Calendrical.Chinese.valid_date?(4662, 1, 1.0)
      refute Calendrical.Persian.valid_date?(1404, nil, 1)
    end
  end

  describe "new/3 checks the day against the traditional month's own length" do
    test "a leap month's days are checked" do
      # Y4660 (= AD 2023): the intercalary 2nd month (閏二月) is ordinal 3, 29 days.
      assert Calendrical.Chinese.days_in_month(4660, 3) == 29

      assert {:ok, ~D[4660-03-29 Calendrical.Chinese]} =
               Calendrical.Chinese.new(4660, {2, :leap}, 29)

      assert {:error, :invalid_date} = Calendrical.Chinese.new(4660, {2, :leap}, 30)
      assert {:error, :invalid_date} = Calendrical.Chinese.new(4660, {2, :leap}, 45)
    end

    test "a month after the leap month is checked against its own length" do
      # Y4662 (= AD 2025): the intercalary 6th month is ordinal 7 (29 days) and
      # the 7th month ordinal 8 (30 days).
      assert Calendrical.Chinese.days_in_month(4662, 7) == 29
      assert Calendrical.Chinese.days_in_month(4662, 8) == 30
      assert {:ok, ~D[4662-08-30 Calendrical.Chinese]} = Calendrical.Chinese.new(4662, 7, 30)

      assert {:ok, ~D[4358-08-30 Calendrical.Korean]} = Calendrical.Korean.new(4358, 7, 30)

      assert {:ok, ~D[4676-07-30 Calendrical.Vietnamese]} =
               Calendrical.Vietnamese.new(4676, 6, 30)

      assert {:ok, ~D[1205-06-30 Calendrical.LunarJapanese]} =
               Calendrical.LunarJapanese.new(1205, 5, 30)
    end

    test "a 30th day of a 29-day month is rejected, not rolled into the next month" do
      assert {:error, :invalid_date} = Calendrical.Chinese.new(4497, 4, 30)
      assert {:error, :invalid_date} = Calendrical.Korean.new(4084, 6, 30)
      assert {:error, :invalid_date} = Calendrical.LunarJapanese.new(1408, 9, 30)
    end

    for calendar <- @lunisolar do
      test "#{inspect(calendar)} rejects months and days outside the year without raising" do
        calendar = unquote(calendar)
        %{year: year} = Date.convert!(~D[2025-06-15], calendar)

        for {month, day} <- [
              {0, 1},
              {13, 1},
              {1, 0},
              {1, -1},
              {1, 31},
              {{0, :leap}, 1},
              {{13, :leap}, 1},
              {:first, 1}
            ] do
          assert {:error, :invalid_date} = calendar.new(year, month, day)
        end
      end
    end
  end

  describe "leap_month?/2 marks only the year's leap month" do
    test "a term-less month after the sui's leap month is not a leap month" do
      # In each of these 12-month years the sui's leap month came before the new
      # year, and month 2 also has no major solar term.
      for {calendar, year} <- [
            {Calendrical.Korean, 4185},
            {Calendrical.LunarJapanese, 1208},
            {Calendrical.Vietnamese, 4861}
          ] do
        assert calendar.leap_month(year) == nil
        refute calendar.leap_month?(year, 2)
      end
    end

    for calendar <- @lunisolar do
      test "#{inspect(calendar)} agrees with each month's traditional label" do
        calendar = unquote(calendar)

        for year <- sample_years(calendar), month <- 1..calendar.months_in_year(year) do
          leap? = match?({_month, :leap}, calendar.lunar_month_of_year(year, month))
          assert calendar.leap_month?(year, month) == leap?, "#{year}-#{month}"
          assert calendar.leap_month(year) == month or not leap?, "#{year}-#{month}"
        end
      end
    end
  end

  describe "ordinal_month/2" do
    for calendar <- @lunisolar do
      test "#{inspect(calendar)} agrees with the month new/3 builds" do
        calendar = unquote(calendar)

        for year <- sample_years(calendar),
            lunar_month <- Enum.to_list(1..12) ++ for(month <- 1..12, do: {month, :leap}) do
          case calendar.new(year, lunar_month, 1) do
            {:ok, date} ->
              assert calendar.ordinal_month(year, lunar_month) == {:ok, date.month}

            {:error, _} ->
              assert {:error, :invalid_leap_month} = calendar.ordinal_month(year, lunar_month)
          end
        end
      end
    end

    test "anything but a traditional month is not one" do
      for lunar_month <- [0, 13, {0, :leap}, {13, :leap}, :first, "1"] do
        assert {:error, :invalid_month} = Calendrical.Chinese.ordinal_month(4662, lunar_month)
      end

      assert {:error, :invalid_month} = Calendrical.Chinese.ordinal_month("4662", 1)
    end
  end

  describe "days_in_month/1" do
    for calendar <- @lunisolar do
      test "#{inspect(calendar)} bounds every month of every year" do
        calendar = unquote(calendar)

        for month <- 1..13, do: assert(calendar.days_in_month(month) == {:ambiguous, 29..30})
        for month <- [0, 14], do: assert(calendar.days_in_month(month) == {:error, :undefined})

        for year <- sample_years(calendar), month <- 1..calendar.months_in_year(year) do
          assert calendar.days_in_month(year, month) in 29..30
        end
      end
    end
  end

  describe "iso_days/3 and Calendrical.iso_days/4" do
    for calendar <- @lunisolar do
      test "#{inspect(calendar)} validates and converts in one pass" do
        calendar = unquote(calendar)

        for year <- sample_years(calendar), month <- -1..14, day <- [-1, 0, 1, 29, 30, 31] do
          expected =
            if calendar.valid_date?(year, month, day),
              do: {:ok, calendar.date_to_iso_days(year, month, day)},
              else: {:error, :invalid_date}

          assert calendar.iso_days(year, month, day) == expected, "#{year}-#{month}-#{day}"
          assert Calendrical.iso_days(year, month, day, calendar) == expected
        end
      end
    end

    test "any calendar validates, then converts" do
      assert Calendrical.iso_days(2024, 2, 29, Calendrical.Gregorian) ==
               {:ok, Date.to_gregorian_days(~D[2024-02-29])}

      assert Calendrical.iso_days(2024, 2, 29, Calendar.ISO) ==
               {:ok, Date.to_gregorian_days(~D[2024-02-29])}

      assert {:error, :invalid_date} = Calendrical.iso_days(2023, 2, 29, Calendrical.Gregorian)
      assert {:error, :invalid_date} = Calendrical.iso_days(1446, 0, 1, Calendrical.Islamic.Civil)
      assert {:error, :invalid_date} = Calendrical.iso_days(2025, 1, 1.5, Calendrical.Gregorian)

      assert {:error, %Calendrical.InvalidCalendarModuleError{}} =
               Calendrical.iso_days(2025, 1, 1, :not_a_calendar)
    end
  end
end
