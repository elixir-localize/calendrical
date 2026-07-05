defmodule Calendrical.CoverageTest.MonthBeginning do
  @moduledoc false

  # Defined at test-load time (rather than in test/support) so that the
  # `Calendrical.Base.Month.__using__/1` macro executes while the module
  # is cover-compiled. Uses the `year: :beginning` setting that no other
  # calendar exercises.
  use Calendrical.Base.Month,
    month_of_year: 7,
    year: :beginning,
    first_or_last: :last
end

defmodule Calendrical.CoverageTest.WeekEnding do
  @moduledoc false

  # As above, for `Calendrical.Base.Week.__using__/1` and the
  # `year: :ending` setting.
  use Calendrical.Base.Week,
    day_of_week: 1,
    month_of_year: 7,
    year: :ending,
    first_or_last: :first,
    weeks_in_month: [4, 5, 4],
    min_days_in_first_week: 4
end

defmodule CoverageBasesTest do
  @moduledoc """
  Coverage tests for `Calendrical.Base.Month` and `Calendrical.Base.Week`,
  exercised through the compiler-built calendars (`Calendrical.Gregorian`,
  `Calendrical.ISOWeek`, `Calendrical.NRF`, `Calendrical.ISO`, the fiscal
  test-support calendars and the runtime-defined calendars above).

  """

  use ExUnit.Case, async: true

  require Calendrical.Base.Month
  require Calendrical.Base.Week

  alias Calendrical.Base.{Month, Week}
  alias Calendrical.{Gregorian, ISOWeek, NRF, CSCO, BasicWeek, Config}
  alias Calendrical.CoverageTest.{MonthBeginning, WeekEnding}

  describe "Base guards" do
    test "is_date guards accept integer triples and date-shaped maps" do
      assert Month.is_date(2025, 1, 1)
      refute Month.is_date(2025, nil, 1)
      assert Month.is_date(%{year: 2025, month: 1, day: 1})
      assert Week.is_date(2025, 1, 1)
      refute Week.is_date(2025, 1, nil)
      assert Week.is_date(%{year: 2025, month: 1, day: 1})
    end
  end

  describe "Base.Month year_of_era across :year settings" do
    test ":ending uses the ending Gregorian year (Fiscal.AU)" do
      assert Calendrical.Fiscal.AU.year_of_era(2019) == {2020, 1}
    end

    test ":beginning uses the beginning Gregorian year" do
      assert MonthBeginning.year_of_era(2019) == {2018, 1}
    end

    test ":majority with a start month in the first half (Fiscal.UK)" do
      assert Calendrical.Fiscal.UK.year_of_era(2019) == {2019, 1}
    end

    test ":majority with a start month in the second half (Fiscal.US)" do
      assert Calendrical.Fiscal.US.year_of_era(2019) == {2019, 1}
    end
  end

  describe "Base.Month week and day functions" do
    test "week_of_year for a day_of_week: :first calendar" do
      assert BasicWeek.week_of_year(2019, 2, 3) == {2019, 5}
    end

    test "week_of_month for a day_of_week: :first calendar" do
      assert BasicWeek.week_of_month(2019, 2, 3) == {2, 1}
    end

    test "day_of_week for a day_of_week: :first calendar" do
      assert BasicWeek.day_of_week(2019, 1, 10, :default) == {3, 1, 7}
    end

    test "week_of_year for a fixed start-of-week calendar" do
      assert Gregorian.week_of_year(2019, 1, 1) == {2019, 1}
      assert Calendrical.Fiscal.AU.week_of_year(2019, 1, 1) == {2019, 1}
      assert Calendrical.Fiscal.UK.week_of_year(2019, 1, 1) == {2019, 1}
      assert Calendrical.Fiscal.US.week_of_year(2019, 1, 1) == {2019, 1}
    end

    test "iso_week_of_year" do
      assert Gregorian.iso_week_of_year(2019, 1, 1) == {2019, 1}
    end

    test "day_of_year" do
      assert Gregorian.day_of_year(2019, 2, 1) == 32
      assert Calendrical.Fiscal.US.day_of_year(2019, 1, 1) == 1
    end

    test "day_of_week with explicit weekday starts" do
      assert Gregorian.day_of_week(2026, 7, 5, :monday) == {7, 1, 7}
      assert Gregorian.day_of_week(2026, 7, 5, :tuesday) == {6, 1, 7}
      assert Gregorian.day_of_week(2026, 7, 5, :wednesday) == {5, 1, 7}
      assert Gregorian.day_of_week(2026, 7, 5, :thursday) == {4, 1, 7}
      assert Gregorian.day_of_week(2026, 7, 5, :friday) == {3, 1, 7}
      assert Gregorian.day_of_week(2026, 7, 5, :saturday) == {2, 1, 7}
      assert Gregorian.day_of_week(2026, 7, 5, :sunday) == {1, 1, 7}
    end

    test "day_of_week with an unsupported starting_on raises" do
      assert_raise ArgumentError, ~r/starting_on :bogus is not supported/, fn ->
        Gregorian.day_of_week(2026, 7, 5, :bogus)
      end
    end
  end

  describe "Base.Month weeks_in_year and days_in_month" do
    test "weeks_in_year for a day_of_week: :first calendar has a partial last week" do
      assert BasicWeek.weeks_in_year(2019) == {53, 1}
      assert BasicWeek.weeks_in_year(2020) == {53, 2}
    end

    test "weeks_in_year long and normal for fixed start-of-week configs" do
      assert Gregorian.weeks_in_year(2020) == {52, 7}
      assert Calendrical.ISO.weeks_in_year(2020) == {53, 7}
      assert Calendrical.Fiscal.US.weeks_in_year(2019) == {52, 7}
    end

    test "days_in_month/1 for a January-anchored calendar" do
      assert Gregorian.days_in_month(2) == {:ambiguous, 28..29}
      assert Gregorian.days_in_month(4) == 30
      assert Gregorian.days_in_month(1) == 31
    end

    test "days_in_month/1 for a shifted-month calendar maps to the Gregorian month" do
      assert Calendrical.Fiscal.US.days_in_month(1) == 31
      assert Calendrical.Fiscal.US.days_in_month(5) == {:ambiguous, 28..29}
    end

    test "days_in_month/1 outside the month range is undefined" do
      assert Gregorian.days_in_month(13) == {:error, :undefined}
    end

    test "days_in_week/2" do
      assert Month.days_in_week(2019, 1) == 7
    end
  end

  describe "Base.Month range functions" do
    test "quarter/2" do
      assert Gregorian.quarter(2019, 2) ==
               Date.range(
                 ~D[2019-04-01 Calendrical.Gregorian],
                 ~D[2019-06-30 Calendrical.Gregorian]
               )

      assert Gregorian.quarter(2019, 5) == {:error, :invalid_date}
    end

    test "month/2" do
      assert Gregorian.month(2019, 2) ==
               Date.range(
                 ~D[2019-02-01 Calendrical.Gregorian],
                 ~D[2019-02-28 Calendrical.Gregorian]
               )

      assert Gregorian.month(2019, 13) == {:error, :invalid_date}
    end

    test "week/2 for a fixed start-of-week calendar" do
      assert Gregorian.week(2019, 5) ==
               Date.range(
                 ~D[2019-01-28 Calendrical.Gregorian],
                 ~D[2019-02-03 Calendrical.Gregorian]
               )

      assert Gregorian.week(2019, 54) == {:error, :invalid_date}
    end

    test "week/2 for a day_of_week: :first calendar clamps the partial last week" do
      assert BasicWeek.week(2019, 5) ==
               Date.range(
                 ~D[2019-01-29 Calendrical.BasicWeek],
                 ~D[2019-02-04 Calendrical.BasicWeek]
               )

      assert BasicWeek.week(2019, 53) ==
               Date.range(
                 ~D[2019-12-31 Calendrical.BasicWeek],
                 ~D[2019-12-31 Calendrical.BasicWeek]
               )

      assert BasicWeek.week(2019, 55) == {:error, :invalid_date}
    end

    test "year/1" do
      assert BasicWeek.year(2019) ==
               Date.range(
                 ~D[2019-01-01 Calendrical.BasicWeek],
                 ~D[2019-12-31 Calendrical.BasicWeek]
               )
    end
  end

  describe "Base.Month plus/7" do
    test "plus :quarters" do
      assert Gregorian.plus(2019, 1, 1, :quarters, 2) == {2019, 7, 1}
      assert Gregorian.plus(2019, 1, 1, :quarters, -1) == {2018, 10, 1}
    end

    test "plus :weeks" do
      assert Gregorian.plus(2019, 1, 1, :weeks, 2) == {2019, 1, 15}
      assert Calendrical.Fiscal.US.plus(2019, 1, 1, :weeks, 2) == {2019, 1, 15}
    end

    test "plus :months wrapping into the prior year" do
      assert Gregorian.plus(2025, 1, 1, :months, -3) == {2024, 10, 1}
    end

    test "plus :months without coercion keeps the day" do
      assert Gregorian.plus(2025, 1, 31, :months, -3, coerce: false) == {2024, 10, 31}
    end

    test "plus :years coerces a leap day" do
      assert Gregorian.plus(2020, 2, 29, :years, 1) == {2021, 2, 28}
    end
  end

  describe "Base.Month error returns for missing fields" do
    test "period functions return MissingFieldsError tuples" do
      assert {:error, %Calendrical.MissingFieldsError{function: "quarter_of_year"}} =
               Gregorian.quarter_of_year(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "month_of_year"}} =
               Gregorian.month_of_year(1, nil, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "week_of_year"}} =
               Gregorian.week_of_year(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "iso_week_of_year"}} =
               Gregorian.iso_week_of_year(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "week_of_month"}} =
               Gregorian.week_of_month(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "day_of_era"}} =
               Gregorian.day_of_era(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "day_of_year"}} =
               Gregorian.day_of_year(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "day_of_week"}} =
               Gregorian.day_of_week(nil, 1, 1, :default)
    end

    test "count functions return MissingFieldsError tuples" do
      assert {:error, %Calendrical.MissingFieldsError{function: "months_in_year"}} =
               Month.months_in_year(nil, Gregorian.__config__())

      assert {:error, %Calendrical.MissingFieldsError{function: "weeks_in_year"}} =
               Gregorian.weeks_in_year(nil)

      assert {:error, %Calendrical.MissingFieldsError{function: "days_in_year"}} =
               Gregorian.days_in_year(nil)

      assert {:error, %Calendrical.MissingFieldsError{function: "days_in_month"}} =
               Gregorian.days_in_month(nil)
    end
  end

  describe "Base.Week year_of_era across :year settings" do
    test ":ending uses the ending Gregorian year" do
      assert WeekEnding.year_of_era(2019) == {2020, 1}
    end

    test ":beginning uses the beginning Gregorian year" do
      config = %Config{year: :beginning, first_or_last: :last, month_of_year: 7}
      assert Week.year_of_era(2019, config) == {2018, 1}
    end

    test ":majority with a start month in the second half (CSCO)" do
      assert CSCO.year_of_era(2019) == {2019, 1}
    end
  end

  describe "Base.Week week and day functions" do
    test "week_of_year and iso_week_of_year" do
      assert NRF.week_of_year(2019, 5, 3) == {2019, 5}
      assert NRF.iso_week_of_year(2019, 5, 3) == {2019, 10}
      assert ISOWeek.iso_week_of_year(2020, 5, 3) == {2020, 5}
    end

    test "day_of_year" do
      assert NRF.day_of_year(2019, 5, 3) == 32
    end

    test "day_of_week with the default and explicit weekday starts" do
      assert NRF.day_of_week(2019, 1, 1, :default) == {1, 1, 7}
      assert NRF.day_of_week(2019, 1, 1, :monday) == {7, 1, 7}
    end

    test "valid_date? respects the number of weeks in the year" do
      assert NRF.valid_date?(2023, 53, 1)
      refute NRF.valid_date?(2022, 53, 1)
    end
  end

  describe "Base.Week weeks_in_year and days_in_month" do
    test "weeks_in_year long and normal years" do
      assert NRF.weeks_in_year(2023) == {53, 7}
      assert ISOWeek.weeks_in_year(2020) == {53, 7}
      assert ISOWeek.weeks_in_year(2021) == {52, 7}
    end

    test "days_in_month/2 for month 12 gains a week in a long year" do
      assert NRF.days_in_month(2023, 12) == 35
    end

    test "days_in_month/1 for month 12 is ambiguous, other months fixed" do
      assert NRF.days_in_month(12) == {:ambiguous, [28, 35]}
      assert NRF.days_in_month(1) == 28
    end

    test "days_in_week/2" do
      assert Week.days_in_week(2019, 1) == 7
    end
  end

  describe "Base.Week range functions" do
    test "year/1" do
      assert NRF.year(2023) ==
               Date.range(~D[2023-W01-1 Calendrical.NRF], ~D[2023-W53-7 Calendrical.NRF])
    end

    test "quarter/2 includes the leap week in the fourth quarter of a long year" do
      assert NRF.quarter(2023, 4) ==
               Date.range(~D[2023-W40-1 Calendrical.NRF], ~D[2023-W53-7 Calendrical.NRF])

      assert NRF.quarter(2023, 5) == {:error, :invalid_date}
    end

    test "month/2 for the last month of a long year" do
      assert NRF.month(2023, 12) ==
               Date.range(~D[2023-W49-1 Calendrical.NRF], ~D[2023-W53-7 Calendrical.NRF])
    end

    test "week/2" do
      assert NRF.week(2023, 53) ==
               Date.range(~D[2023-W53-1 Calendrical.NRF], ~D[2023-W53-7 Calendrical.NRF])

      assert NRF.week(2023, 54) == {:error, :invalid_date}
    end
  end

  describe "Base.Week plus/7 and add_days" do
    test "plus :quarters" do
      assert NRF.plus(2019, 1, 1, :quarters, 1) == {2019, 14, 1}
    end

    test "plus :months with a zero increment" do
      assert NRF.plus(2019, 5, 3, :months, 0) == {2019, 5, 3}
    end

    test "plus :months forwards and backwards" do
      assert NRF.plus(2019, 4, 6, :months, 2) == {2019, 13, 6}
      assert NRF.plus(2019, 9, 6, :months, -2) == {2018, 52, 7}
      assert NRF.plus(2019, 5, 7, :months, 2) == {2019, 14, 7}
    end

    test "plus :days" do
      assert NRF.plus(2019, 1, 1, :days, 10) == {2019, 2, 4}
    end

    test "add_days with coercion clamps to the month" do
      assert Week.add_days(2019, 1, 1, 3, NRF.__config__(), coerce: true) == {2019, 1, 4}
      assert Week.add_days(2019, 1, 1, 40, NRF.__config__(), coerce: true) == {2019, 4, 7}
    end

    test "add_days without coercion adds the raw day count" do
      assert Week.add_days(2019, 1, 1, 40, NRF.__config__(), coerce: false) == {2019, 6, 6}
    end

    test "add/3 shifts the year of a week date" do
      assert Week.add(~D[2019-W05-3 Calendrical.NRF], :year, 1) ==
               ~D[2020-W05-3 Calendrical.NRF]
    end
  end

  describe "Base.Week string conversions and helpers" do
    test "date_to_string pads single-digit weeks" do
      assert Week.date_to_string(2019, 5, 3) == "2019-W05-3"
      assert Week.date_to_string(2019, 12, 3) == "2019-W12-3"
    end

    test "naive_datetime_to_string and datetime_to_string" do
      assert Week.naive_datetime_to_string(2019, 5, 3, 1, 2, 3, {0, 0}) == "2019-W05-3 01:02:03"

      assert Week.datetime_to_string(2019, 5, 3, 1, 2, 3, {0, 0}, "Etc/UTC", "UTC", 0, 0) ==
               "2019-W05-3 01:02:03Z"
    end

    test "sign/1" do
      assert Week.sign(-5) == -1
      assert Week.sign(5) == 1
    end
  end

  describe "Base.Week error returns for missing fields" do
    test "period functions return MissingFieldsError tuples" do
      assert {:error, %Calendrical.MissingFieldsError{function: "week_of_year"}} =
               NRF.week_of_year(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "iso_week_of_year"}} =
               Week.iso_week_of_year(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "week_of_month"}} =
               NRF.week_of_month(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "day_of_era"}} =
               NRF.day_of_era(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "day_of_year"}} =
               NRF.day_of_year(nil, 1, 1)

      assert {:error, %Calendrical.MissingFieldsError{function: "day_of_week"}} =
               NRF.day_of_week(2019, 1, nil, :default)
    end

    test "count functions return MissingFieldsError tuples" do
      assert {:error, %Calendrical.MissingFieldsError{function: "months_in_year"}} =
               Week.months_in_year(nil, NRF.__config__())

      assert {:error, %Calendrical.MissingFieldsError{function: "weeks_in_year"}} =
               NRF.weeks_in_year(nil)

      assert {:error, %Calendrical.MissingFieldsError{function: "days_in_year"}} =
               NRF.days_in_year(nil)

      assert {:error, %Calendrical.MissingFieldsError{function: "days_in_month"}} =
               Week.days_in_month(nil, %{})
    end
  end
end
