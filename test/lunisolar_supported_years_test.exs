defmodule Calendrical.LunisolarSupportedYearsTest do
  # A lunisolar calendar answers for the 40,001 years numbered, from the
  # Gregorian year of its epoch, as Gregorian years -20,000 to 20,000, and
  # refuses the rest at once: far beyond them the new moons it is reckoned
  # from drift from their mean timing faster than a search can follow.
  use ExUnit.Case, async: true

  @calendars [
    Calendrical.Chinese,
    Calendrical.Korean,
    Calendrical.Vietnamese,
    Calendrical.LunarJapanese
  ]

  defp supported_years(calendar) do
    epoch = calendar.epoch() |> Date.from_gregorian_days() |> Date.convert!(Calendar.ISO)
    Calendrical.Calendar.Lunisolar.supported_years(epoch, -20_000..20_000)
  end

  test "Calendrical.Chinese answers for its years -17,363 to 22,637" do
    assert supported_years(Calendrical.Chinese) == -17_363..22_637
  end

  for calendar <- @calendars do
    describe "#{inspect(calendar)}" do
      test "the first and last supported years are dates and read back" do
        calendar = unquote(calendar)
        first..last//1 = supported_years(calendar)

        assert calendar.valid_date?(first, 1, 1)

        assert calendar.date_from_iso_days(calendar.date_to_iso_days(first, 1, 1)) ==
                 {first, 1, 1}

        last_month = calendar.months_in_year(last)
        last_day = calendar.days_in_month(last, last_month)
        assert calendar.valid_date?(last, last_month, last_day)

        assert calendar.date_from_iso_days(calendar.date_to_iso_days(last, last_month, last_day)) ==
                 {last, last_month, last_day}
      end

      test "a year beyond them is no date, and is refused at once" do
        calendar = unquote(calendar)
        first..last//1 = supported_years(calendar)

        {microseconds, answers} =
          :timer.tc(fn ->
            for year <- [first - 1, last + 1, 1_000_000, 99_999_999, -99_999_999] do
              calendar.valid_date?(year, 1, 1)
            end
          end)

        assert Enum.all?(answers, &(&1 == false))
        assert microseconds < 1_000_000

        assert {:error, %Calendrical.UnsupportedDateRangeError{calendar: ^calendar}} =
                 calendar.new(last + 1, 1, 1)

        assert_raise Calendrical.UnsupportedDateRangeError, fn ->
          calendar.date_to_iso_days(last + 1, 1, 1)
        end

        assert_raise Calendrical.UnsupportedDateRangeError, fn ->
          calendar.leap_year?(last + 1)
        end

        assert_raise Calendrical.UnsupportedDateRangeError, fn ->
          calendar.date_from_iso_days(Calendar.ISO.date_to_iso_days(1_000_000, 1, 1))
        end

        assert_raise Calendrical.UnsupportedDateRangeError, fn ->
          calendar.gregorian_date_for_lunar(20_001, 1, 1)
        end
      end
    end
  end

  test "diff/3 counts up to the last supported year without stepping past it" do
    chinese = Calendrical.Chinese

    assert Calendrical.diff(
             Date.new!(22_636, 1, 1, chinese),
             Date.new!(22_637, 1, 1, chinese),
             :years
           ) ==
             1

    assert Calendrical.diff(
             Date.new!(22_637, 1, 1, chinese),
             Date.new!(22_637, 13, 29, chinese),
             :months
           ) ==
             12
  end

  test "Calendrical.Lunisolar refuses a day far outside the supported years at once" do
    location = &Calendrical.Chinese.location/1

    assert_raise Calendrical.UnsupportedDateRangeError, fn ->
      Calendrical.Lunisolar.new_moon_on_or_after(
        Calendar.ISO.date_to_iso_days(1_000_000, 1, 1),
        location
      )
    end

    assert_raise Calendrical.UnsupportedDateRangeError, fn ->
      Calendrical.Lunisolar.leap_year?(1_000_000, Calendrical.Chinese.epoch(), location)
    end

    # A fractional moment inside the range is answered.
    assert is_integer(Calendrical.Lunisolar.new_moon_on_or_after(739_038.5, location))
  end

  test "a composite year with no days of its own is no leap year" do
    assert Calendrical.Reform.Japan.leap_year?(-20_645) == false
    assert Calendrical.Reform.Japan.months_in_year(-20_645) == 0
  end
end
