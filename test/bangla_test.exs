defmodule Calendrical.BanglaTest do
  use ExUnit.Case, async: true

  # The Bangla calendar of Bangladesh: the 1987 Bangla Academy rules, the
  # 2019 revision, and the composite that keeps each in its own time. Its
  # months are named from CLDR's Indian calendar, begun one month later.

  alias Calendrical.Bangla
  alias Calendrical.Bangla.Revised1987
  alias Calendrical.Bangla.Revised2019

  doctest Calendrical.Bangla
  doctest Calendrical.Bangla.Revised1987
  doctest Calendrical.Bangla.Revised2019

  # The days date-holidays writes in the 1987 rules, against the
  # Gregorian day each falls on in every year.
  @national_days_1987 [
    {{11, 9}, {2, 21}, "Language Martyrs' Day"},
    {{12, 3}, {3, 17}, "Mujib's Birthday"},
    {{12, 12}, {3, 26}, "Independence Day"},
    {{1, 1}, {4, 14}, "Pohela Boishakh"},
    {{1, 18}, {5, 1}, "May Day"},
    {{4, 31}, {8, 15}, "National Mourning Day"},
    {{9, 2}, {12, 16}, "Victory Day"},
    {{9, 11}, {12, 25}, "Christmas"}
  ]

  # The days the 2019 revision was made to fall on.
  @national_days_2019 [
    {{11, 8}, {2, 21}, "Language Martyrs' Day"},
    {{12, 12}, {3, 26}, "Independence Day"},
    {{1, 1}, {4, 14}, "Pohela Boishakh"},
    {{4, 21}, {8, 5}, "July Uprising Day"},
    {{9, 1}, {12, 16}, "Victory Day"}
  ]

  defp gregorian(calendar, year, month, day) do
    {:ok, date} = Date.new(year, month, day, calendar)
    Date.convert!(date, Calendar.ISO)
  end

  # The Gregorian year a day of a Bangla year falls in: the year begins on
  # 14 April, so its months from Magh fall in the next Gregorian year.
  defp gregorian_year(year, {month, day}) do
    if {month, day} >= {4, 14} do
      year + 593
    else
      year + 594
    end
  end

  describe "the national days fall on the same Gregorian day every year" do
    for {calendar, days} <- [
          {Revised1987, @national_days_1987},
          {Revised2019, @national_days_2019}
        ],
        {{month, day}, gregorian_day, name} <- days do
      @calendar calendar
      @month month
      @day day
      @gregorian_day gregorian_day

      test "#{inspect(calendar)}: #{name}, #{month}-#{day}" do
        {gregorian_month, gregorian_day} = @gregorian_day

        for year <- 1390..1440 do
          expected =
            Date.new!(gregorian_year(year, @gregorian_day), gregorian_month, gregorian_day)

          assert gregorian(@calendar, year, @month, @day) == expected
        end
      end
    end
  end

  describe "the shape of a year" do
    test "the 1987 rules: five months of 31 days, and Falgun of 31 in a leap year" do
      assert Enum.map(1..12, &Revised1987.days_in_month(1431, &1)) ==
               [31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30, 30]

      assert Revised1987.days_in_month(1430, 11) == 31
    end

    test "the 2019 rules: six months of 31 days, and Falgun of 29, or 30 in a leap year" do
      assert Enum.map(1..12, &Revised2019.days_in_month(1431, &1)) ==
               [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 29, 30]

      assert Revised2019.days_in_month(1430, 11) == 30
    end

    test "a year is a leap year when its Falgun falls in a Gregorian leap year" do
      for year <- 1000..1500 do
        assert Revised1987.leap_year?(year) == Calendar.ISO.leap_year?(year + 594)
        assert Revised2019.leap_year?(year) == Revised1987.leap_year?(year)
      end
    end

    test "every day round-trips through its ISO day number" do
      for calendar <- [Revised1987, Revised2019, Bangla], iso_days <- -200_000..900_000//97 do
        {year, month, day} = calendar.date_from_iso_days(iso_days)

        assert calendar.valid_date?(year, month, day)
        assert calendar.date_to_iso_days(year, month, day) == iso_days
      end
    end

    test "a month the year does not have is an error, not a crash" do
      for calendar <- [Revised1987, Revised2019] do
        assert {:error, %Calendrical.InvalidMonthError{month: 13}} =
                 calendar.days_in_month(1431, 13)

        refute calendar.valid_date?(1431, 13, 1)
      end
    end
  end

  describe "the composite keeps each revision in its own time" do
    test "the 1987 rules until 15 October 2019, the 2019 rules from the 16th" do
      assert Date.convert!(~D[2019-10-15], Bangla) == ~D[1426-06-30 Calendrical.Bangla]
      assert Date.convert!(~D[2019-10-16], Bangla) == ~D[1426-06-31 Calendrical.Bangla]
      assert Date.convert!(~D[2019-10-17], Bangla) == ~D[1426-07-01 Calendrical.Bangla]
    end

    test "Victory Day is 2 Poush before the revision and 1 Poush after it" do
      assert Date.convert!(~D[2018-12-16], Bangla) == ~D[1425-09-02 Calendrical.Bangla]
      assert Date.convert!(~D[2019-12-16], Bangla) == ~D[1426-09-01 Calendrical.Bangla]
    end

    test "agrees with the 1987 rules before the change and the 2019 rules after it" do
      change = Date.to_gregorian_days(~D[2019-10-16])

      for iso_days <- (change - 20_000)..(change + 20_000)//7 do
        expected =
          if iso_days < change do
            Revised1987.date_from_iso_days(iso_days)
          else
            Revised2019.date_from_iso_days(iso_days)
          end

        assert Bangla.date_from_iso_days(iso_days) == expected
      end
    end
  end

  describe "names, from CLDR's Indian calendar" do
    test "Boishakh is named Boishakh and written as month 1" do
      date = ~D[1432-01-01 Calendrical.Bangla]

      assert Localize.Date.to_string(date, locale: :bn, format: :long) ==
               {:ok, "১ বৈশাখ, ১৪৩২ বঙ্গাব্দ"}

      assert Localize.Date.to_string(date, locale: :bn, format: :short) ==
               {:ok, "১/১/১৪৩২ বঙ্গাব্দ"}
    end

    test "Choitro, the last month, is named as the Indian calendar's first" do
      assert {:ok, "১২ চৈত্র, ১৪৩১ বঙ্গাব্দ"} =
               Localize.Date.to_string(~D[1431-12-12 Calendrical.Bangla],
                 locale: :bn,
                 format: :long
               )
    end

    test "every month is named once, and a written date reads back" do
      for calendar <- [Revised1987, Revised2019, Bangla], month <- 1..12 do
        {:ok, date} = Date.new(1432, month, 1, calendar)

        for locale <- [:bn, :en] do
          {:ok, written} = Localize.Date.to_string(date, locale: locale, format: :long)
          assert Localize.Date.parse(written, locale: locale, calendar: calendar) == {:ok, date}
        end
      end
    end

    test "the Indian calendar is named as before" do
      assert Localize.Date.to_string(~D[1947-01-01 Calendrical.Indian],
               locale: :bn,
               format: :long
             ) ==
               {:ok, "১ চৈত্র, ১৯৪৭ সাল"}
    end
  end

  describe "the era, named by the calendar" do
    test "is the Bangla era, not the Indian calendar's Śaka" do
      date = ~D[1432-01-01 Calendrical.Bangla]

      assert Localize.Date.to_string(date, locale: :en, format: :long) ==
               {:ok, "Vaisakha 1, 1432 BS"}

      assert Localize.Date.to_string(date, locale: :en, format: "y GGGG") ==
               {:ok, "1432 Bangabda"}

      assert Localize.Date.to_string(date, locale: :bn, format: "y GGGG") ==
               {:ok, "১৪৩২ বঙ্গাব্দ"}
    end

    test "is the English name in a locale with no translation of it" do
      assert {:ok, "lundi 14 avril 2025" <> _} =
               Localize.Date.to_string(~D[2025-04-14], locale: :fr, format: :full)

      assert {:ok, "01/01/1432 BS"} =
               Localize.Date.to_string(~D[1432-01-01 Calendrical.Bangla],
                 locale: :fr,
                 format: :short
               )
    end

    test "is answered by every Bangla calendar, at each width" do
      for calendar <- [Revised1987, Revised2019, Bangla] do
        assert calendar.era_names(:en) ==
                 {:ok,
                  %{wide: %{0 => "Bangabda"}, abbreviated: %{0 => "BS"}, narrow: %{0 => "BS"}}}

        assert {:ok, %{wide: %{0 => "বঙ্গাব্দ"}}} = calendar.era_names(:bn)
      end
    end

    test "a calendar that names no era of its own leaves it to CLDR" do
      assert Calendrical.Indian.era_names(:en) == :cldr
      assert Calendrical.Gregorian.era_names(:bn) == :cldr

      assert Localize.Date.to_string(~D[1947-01-01 Calendrical.Indian],
               locale: :en,
               format: :long
             ) ==
               {:ok, "Chaitra 1, 1947 Śaka"}
    end

    test "a locale that cannot be read is an error" do
      assert {:error, _exception} = Revised1987.era_names("not a locale!")
    end

    test "names that are not the three styles are refused when the calendar compiles" do
      assert_raise Calendrical.InvalidOptionValueError, fn ->
        Code.compile_string("""
        defmodule Validation.BadEraNames do
          use Calendrical.Calendar,
            epoch: ~D[0001-01-01 Calendrical.Gregorian],
            era_names: %{0 => [wide: "Era"]}
        end
        """)
      end
    end
  end

  describe "IXDTF names" do
    test "each calendar is named, and the name reads back to it" do
      for {name, calendar} <- [bangla: Bangla, bangla_1987: Revised1987, bangla_2019: Revised2019] do
        assert Calendrical.additional_calendars()[name] == calendar
        assert Calendrical.calendar_from_cldr_calendar_type(name) == {:ok, calendar}
      end

      assert Calendrical.calendar_from_cldr_calendar_type(:indian) == {:ok, Calendrical.Indian}
    end
  end
end
