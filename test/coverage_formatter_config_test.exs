defmodule Calendrical.Coverage.FormatterConfigTest do
  @moduledoc """
  Coverage tests for `Calendrical.Formatter.Options`,
  `Calendrical.Formatter.HTML.Week`, `Calendrical.Composite`,
  `Calendrical.Composite.Config`, `Calendrical.FiscalYear` and
  `Calendrical.Config`.

  All expected values in this file were probed by executing the functions
  on the development toolchain before being asserted here.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Formatter.Options
  alias Calendrical.Composite
  alias Calendrical.FiscalYear

  # ── Formatter.Options — error paths ──────────────────────────────

  describe "Formatter.Options.validate_options/1 error paths" do
    test "an invalid locale is rejected" do
      assert {:error, %Localize.InvalidLocaleError{locale_id: "zz-invalid!"}} =
               Options.validate_options(locale: "zz-invalid!")
    end

    test "an invalid calendar module is rejected" do
      assert {:error, %Calendrical.InvalidCalendarModuleError{module: NotACalendar}} =
               Options.validate_options(calendar: NotACalendar)
    end

    test "an invalid number system is rejected" do
      assert {:error, %Localize.UnknownNumberSystemError{number_system: :nope}} =
               Options.validate_options(number_system: :nope)
    end

    test "an explicit territory is validated" do
      # :ZZ is a valid private-use code and is accepted.
      assert {:ok, %Options{territory: :ZZ}} = Options.validate_options(territory: :ZZ)

      assert {:error, %Localize.UnknownTerritoryError{}} =
               Options.validate_options(territory: :invalid)
    end

    test "a module that is not a formatter is rejected" do
      assert {:error, %Calendrical.Formatter.UnknownFormatterError{formatter: String}} =
               Options.validate_options(formatter: String)
    end

    test "day_names must be a seven-element indexed list" do
      assert {:error,
              %Calendrical.Formatter.InvalidOptionError{
                option: :day_names,
                value: [{1, "a"}, {2, "b"}]
              }} = Options.validate_options(day_names: [{1, "a"}, {2, "b"}])
    end

    test "today must be a date-shaped map" do
      assert {:error, %Calendrical.Formatter.InvalidDateError{date: :not_a_date}} =
               Options.validate_options(today: :not_a_date)
    end
  end

  describe "Formatter.Options.validate_options/1 valid paths" do
    test "the :backend key is silently dropped" do
      assert {:ok, %Options{} = options} = Options.validate_options(backend: SomeBackend)
      refute Map.has_key?(Map.from_struct(options), :backend)
      assert options.calendar == Calendrical.Gregorian
    end

    test "Calendar.ISO is normalised to the default calendar" do
      assert {:ok, %Options{calendar: Calendrical.Gregorian}} =
               Options.validate_options(calendar: Calendar.ISO)
    end

    test "explicit caption, id, class, private and day_names pass through" do
      day_names = [{1, "a"}, {2, "b"}, {3, "c"}, {4, "d"}, {5, "e"}, {6, "f"}, {7, "g"}]

      assert {:ok, %Options{} = options} =
               Options.validate_options(
                 day_names: day_names,
                 caption: "Cap",
                 id: "id1",
                 class: "cls",
                 private: %{x: 1}
               )

      assert options.caption == "Cap"
      assert options.id == "id1"
      assert options.class == "cls"
      assert options.private == %{x: 1}
      assert options.day_names == day_names
    end

    test "an explicit valid today date passes through" do
      assert {:ok, %Options{today: ~D[2024-06-01]}} =
               Options.validate_options(today: ~D[2024-06-01])
    end
  end

  # ── Formatter.HTML.Week ─────────────────────────────────────────

  describe "Formatter.HTML.Week" do
    test "renders a month of a week-based calendar with week indicators" do
      month =
        Calendrical.Format.month(2019, 4,
          formatter: Calendrical.Formatter.HTML.Week,
          calendar: Calendrical.ISOWeek
        )

      assert is_binary(month)
      assert String.starts_with?(month, "<table")
      assert String.contains?(month, "W14")
      # The day-name header row starts with a blank spacer cell for
      # the week-indicator column.
      assert String.contains?(month, "<td> </td>")
    end

    test "single-digit week numbers are left-padded" do
      month =
        Calendrical.Format.month(2019, 1,
          formatter: Calendrical.Formatter.HTML.Week,
          calendar: Calendrical.ISOWeek
        )

      assert String.contains?(month, "W01")
      assert String.contains?(month, "W04")
    end

    test "explicit caption, id and class are rendered" do
      month =
        Calendrical.Format.month(2019, 4,
          formatter: Calendrical.Formatter.HTML.Week,
          calendar: Calendrical.Gregorian,
          caption: "My Week Cap",
          id: "wk",
          class: "wkcls"
        )

      assert String.contains?(month, "<caption>My Week Cap</caption>")
      assert String.contains?(month, ~s(id="wk"))
      assert String.contains?(month, ~s(<table class="wkcls"))
    end

    test "renders a full year of a week-based calendar" do
      year =
        Calendrical.Format.year(2019,
          formatter: Calendrical.Formatter.HTML.Week,
          calendar: Calendrical.ISOWeek
        )

      assert String.starts_with?(year, ~s(<div class="cldr_calendar_year">))
      assert String.contains?(year, "W01")
      assert String.contains?(year, "W52")
    end
  end

  # ── Composite calendars ─────────────────────────────────────────

  describe "Composite calendars (England and Russia)" do
    test "England leap years follow the calendar in force" do
      # 1100 is in the Julian era (divisible by 4 → leap); 1900 is in
      # the Gregorian era (century not divisible by 400 → not leap).
      assert Calendrical.England.leap_year?(1100)
      refute Calendrical.England.leap_year?(1900)
    end

    test "England dates convert to the underlying calendars" do
      assert Date.convert(~D[1752-09-14 Calendrical.England], Calendrical.Gregorian) ==
               {:ok, ~D[1752-09-14 Calendrical.Gregorian]}

      assert Date.convert(~D[1752-09-02 Calendrical.England], Calendrical.Julian) ==
               {:ok, ~D[1752-09-02 Calendrical.Julian]}
    end

    test "modern dates convert into a composite calendar unchanged" do
      assert Date.convert(~D[2024-03-11], Calendrical.England) ==
               {:ok, ~D[2024-03-11 Calendrical.England]}
    end

    test "Russia's February 1918 has 15 valid days" do
      assert Calendrical.Russia.days_in_month(1918, 2) == 15
    end

    test "Russia's 1918 has 352 days (13 dropped)" do
      assert Calendrical.Russia.days_in_year(1918) == 352
    end
  end

  describe "Composite.new/2 and Composite.Config" do
    alias Calendrical.Composite.Config

    test "Composite.new/2 rejects a calendars list that is not dates" do
      assert Composite.new(Coverage.BadComposite, calendars: [:nope]) ==
               {:error, :must_be_a_list_of_dates}
    end

    test "validate_options/1 rejects an empty option list" do
      assert Config.validate_options([]) == {:error, :no_calendars_configured}
    end

    test "validate_options/1 wraps a single date into a list" do
      assert Config.validate_options(calendars: ~D[1700-03-01]) ==
               {:ok, [calendars: [~D[1700-03-01]]]}
    end

    test "extract_options/1 prepends the base transition and sorts" do
      assert [
               {-3_651_771, -9999, 1, 1, Calendrical.Julian},
               {640_162, 1752, 9, 14, Calendrical.Gregorian}
             ] = Config.extract_options(calendars: ~D[1752-09-14 Calendrical.Gregorian])
    end

    test "extract_options/1 maps Calendar.ISO to Calendrical.Gregorian" do
      assert [
               {_, -9999, 1, 1, Calendrical.Julian},
               {640_162, 1752, 9, 14, Calendrical.Gregorian}
             ] = Config.extract_options(calendars: [~D[1752-09-14]])
    end

    test "extract_options/1 raises on entries that are not dates" do
      assert_raise ArgumentError, ~r/Unknown date found/, fn ->
        Config.extract_options(calendars: [:not_a_date])
      end
    end

    test "define_transition_functions/2 passes each head with its tail" do
      assert Config.define_transition_functions([1, 2, 3], fn head, tail -> {head, tail} end) ==
               [{1, [2, 3]}, {2, [3]}, {3, []}]
    end
  end

  # ── FiscalYear ──────────────────────────────────────────────────

  describe "FiscalYear.known_fiscal_years/0 and known_fiscal_calendars/0" do
    test "known_fiscal_years/0 returns configurations keyed by territory" do
      fiscal_years = FiscalYear.known_fiscal_years()

      assert fiscal_years[:US] == [calendar: Calendrical.Gregorian, month_of_year: 10]
      assert fiscal_years[:GB] == [calendar: Calendrical.Gregorian, month_of_year: 4]
      assert fiscal_years[:AU] == [calendar: Calendrical.Gregorian, month_of_year: 7]
    end

    test "known_fiscal_calendars/0 lists every configured territory" do
      calendars = FiscalYear.known_fiscal_calendars()

      assert :US in calendars
      assert :AU in calendars
      assert length(calendars) == map_size(FiscalYear.known_fiscal_years())
    end
  end

  describe "FiscalYear.calendar_for/1" do
    test "returns a configured calendar module for a known territory" do
      assert {:ok, calendar} = FiscalYear.calendar_for(:AU)
      assert calendar == Calendrical.FiscalYear.AU
      assert calendar.__config__().month_of_year == 7
    end

    test "is idempotent and accepts string territory codes" do
      assert {:ok, Calendrical.FiscalYear.US} = FiscalYear.calendar_for(:US)
      assert {:ok, Calendrical.FiscalYear.US} = FiscalYear.calendar_for("US")
    end

    test "returns an error for a territory with no fiscal data" do
      assert {:error, %Localize.UnknownCalendarError{calendar: :AQ}} =
               FiscalYear.calendar_for(:AQ)
    end

    test "returns an error for an unknown territory" do
      assert {:error, %Localize.UnknownCalendarError{calendar: :ZZ}} =
               FiscalYear.calendar_for(:ZZ)
    end
  end

  # ── Config validation via Calendrical.new/3 ─────────────────────

  describe "Calendrical.new/3 config validation" do
    test "rejects a :day_of_week outside 1..7" do
      assert Calendrical.new(Coverage.BadDay, :week, day_of_week: 9) ==
               {:error, ":day_of_week must be in the range 1..7. Found 9."}
    end

    test "rejects :day_of_week :first for week calendars" do
      assert Calendrical.new(Coverage.BadFirst, :week, day_of_week: :first) ==
               {:error, ":day_of_week must be in the range 1..7. Found :first."}
    end

    test "accepts :day_of_week :first for month calendars" do
      assert {:ok, Coverage.MonthFirst} =
               Calendrical.new(Coverage.MonthFirst, :month, day_of_week: :first)
    end

    test "rejects a :min_days_in_first_week outside 1..7" do
      assert Calendrical.new(Coverage.BadMinDays, :week, min_days_in_first_week: 9) ==
               {:error, ":min_days_in_first_week must be in the range 1..7. Found 9."}
    end

    test "rejects an unknown :weeks_in_month layout" do
      assert Calendrical.new(Coverage.BadWeeks, :week, weeks_in_month: [3, 3, 3]) ==
               {:error, ":weeks_in_month must be [4,4,5], [4,5,4] or [5,4,4]. Found [3, 3, 3]"}
    end

    test "rejects a :month_of_year outside 1..12" do
      assert Calendrical.new(Coverage.BadMonth, :month, month_of_year: 15) ==
               {:error, ":month_of_year must be in the range 1..12. Found 15."}
    end

    test "rejects an unknown :year policy" do
      assert Calendrical.new(Coverage.BadYear, :week, year: :bogus) ==
               {:error, ":year must be either :beginning, :ending or :majority. Found :bogus."}
    end

    test "rejects an unknown :cldr_calendar_type" do
      assert Calendrical.new(Coverage.BadType, :week, cldr_calendar_type: :hebrew) ==
               {:error,
                ":cldr_calendar_type must be either :gregorian or :japanese. Found :hebrew."}
    end

    test "rejects an unknown :first_or_last" do
      assert Calendrical.new(Coverage.BadFirstOrLast, :week, first_or_last: :middle) ==
               {:error, ":first_or_last must be :first or :last. Found :middle."}
    end

    test "rejects an unknown :begins_or_ends" do
      assert Calendrical.new(Coverage.BadBeginsOrEnds, :week, begins_or_ends: :maybe) ==
               {:error, ":begins_or_ends must be :begins or :ends. Found :maybe."}
    end

    test "raises for the retired :day, :month and :min_days options" do
      assert_raise ArgumentError, "Option :day is replaced with :day_of_week", fn ->
        Calendrical.new(Coverage.OldDay, :week, day: 1)
      end

      assert_raise ArgumentError, "Option :month is replaced with :month_of_year", fn ->
        Calendrical.new(Coverage.OldMonth, :week, month: 1)
      end

      assert_raise ArgumentError,
                   "Option :min_days is replaced with :min_days_in_first_week",
                   fn -> Calendrical.new(Coverage.OldMinDays, :week, min_days: 4) end
    end

    test "raises for unrecognised options" do
      assert_raise ArgumentError, ~r/Invalid options \[bogus_option: 1\] found/, fn ->
        Calendrical.new(Coverage.BogusOption, :week, bogus_option: 1)
      end
    end

    test "returns an already-loaded module without recreating it" do
      assert Calendrical.new(Calendrical.ISOWeek, :week, []) == {:ok, Calendrical.ISOWeek}
    end
  end

  describe "regression: composite transition-year arithmetic" do
    test "England 1751 ran from Lady Day to the year end" do
      # 25 March 1751 through 31 December 1751 (Julian).
      assert Calendrical.England.days_in_year(1751) == 282
      assert Calendrical.England.days_in_month(1751, 3) == 7
    end

    test "England 1752 lost eleven days in September" do
      assert Calendrical.England.days_in_year(1752) == 355
      assert Calendrical.England.days_in_month(1752, 9) == 19
    end
  end
end
