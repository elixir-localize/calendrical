defmodule Calendrical.CoverageWrappersTest do
  use ExUnit.Case, async: true

  # Coverage for the Calendrical.Date, Calendrical.DateTime and
  # Calendrical.Time parse wrappers and Calendrical.MissingFieldsError.

  describe "Calendrical.Date.parse/2" do
    test "parses an ISO date" do
      assert Calendrical.Date.parse("2026-05-16", locale: :en) == {:ok, ~D[2026-05-16]}
    end

    test "parses an ISO date with default options" do
      assert Calendrical.Date.parse("2026-05-16") == {:ok, ~D[2026-05-16]}
    end

    test "returns a partial field map with as: :map" do
      assert Calendrical.Date.parse("May 5", locale: :en, as: :map) ==
               {:ok, %{calendar: Calendar.ISO, month: 5, day: 5}}

      assert Calendrical.Date.parse("2026", locale: :en, as: :map) ==
               {:ok, %{calendar: Calendar.ISO, year: 2026}}
    end

    test "returns an error for unparseable input" do
      assert {:error, %Calendrical.DateParseError{input: "not a date", locale: :en}} =
               Calendrical.Date.parse("not a date", locale: :en)
    end
  end

  describe "Calendrical.Date.parse_range/2" do
    test "parses a tuple of endpoint strings" do
      assert {:ok, range} = Calendrical.Date.parse_range({"2026-05-05", "2026-05-10"})
      assert range.first == ~D[2026-05-05]
      assert range.last == ~D[2026-05-10]
    end

    test "parses a single string with as: :map" do
      assert Calendrical.Date.parse_range("May 5 – May 10, 2026", locale: :en, as: :map) ==
               {:ok,
                {%{calendar: Calendar.ISO, year: 2026, month: 5, day: 5},
                 %{calendar: Calendar.ISO, year: 2026, month: 5, day: 10}}}
    end

    test "returns an error when no separator is found" do
      assert {:error, %Calendrical.DateRangeParseError{reason: :no_separator}} =
               Calendrical.Date.parse_range("gibberish input", locale: :en)
    end

    test "rejects an inverted range by default" do
      assert {:error, %Calendrical.DateRangeParseError{reason: :inverted}} =
               Calendrical.Date.parse_range({"2026-05-10", "2026-05-05"}, locale: :en)
    end

    test "allows an inverted range with allow_inverted: true" do
      assert {:ok, range} =
               Calendrical.Date.parse_range({"2026-05-10", "2026-05-05"},
                 locale: :en,
                 allow_inverted: true
               )

      assert range.first == ~D[2026-05-10]
      assert range.last == ~D[2026-05-05]
      assert range.step == -1
    end
  end

  describe "Calendrical.Time.parse/2" do
    test "parses ISO and locale-formatted times" do
      assert Calendrical.Time.parse("14:30:00", locale: :en) == {:ok, ~T[14:30:00]}
      assert Calendrical.Time.parse("2:30 PM", locale: :en) == {:ok, ~T[14:30:00]}
    end

    test "parses an ISO time with default options" do
      assert Calendrical.Time.parse("14:30:00") == {:ok, ~T[14:30:00]}
    end

    test "returns a partial field map with as: :map" do
      assert Calendrical.Time.parse("11 am", locale: :en, as: :map) == {:ok, %{hour: 11}}

      assert Calendrical.Time.parse("11:30", locale: :en, as: :map) ==
               {:ok, %{hour: 11, minute: 30}}
    end

    test "returns an error for unparseable input" do
      assert {:error, %Calendrical.TimeParseError{input: "zzz", locale: :en}} =
               Calendrical.Time.parse("zzz", locale: :en)
    end
  end

  describe "Calendrical.DateTime.parse/2" do
    test "parses a datetime string" do
      assert Calendrical.DateTime.parse("2026-05-16 14:30:00", locale: :en) ==
               {:ok, ~N[2026-05-16 14:30:00]}
    end

    test "parses an ISO datetime with default options" do
      assert Calendrical.DateTime.parse("2026-05-16 14:30:00") ==
               {:ok, ~N[2026-05-16 14:30:00]}
    end

    test "returns a field map with as: :map" do
      assert Calendrical.DateTime.parse("2026-05-16 14:30:00", locale: :en, as: :map) ==
               {:ok,
                %{
                  calendar: Calendar.ISO,
                  year: 2026,
                  month: 5,
                  day: 16,
                  hour: 14,
                  minute: 30,
                  second: 0
                }}
    end

    test "returns an error for unparseable input" do
      assert {:error, %Calendrical.DateTimeParseError{input: "zzz", locale: :en}} =
               Calendrical.DateTime.parse("zzz", locale: :en)
    end
  end

  describe "Calendrical.MissingFieldsError" do
    test "message with several fields" do
      error =
        Calendrical.MissingFieldsError.exception(
          function: "localize",
          fields: [year: 2026, month: nil, day: nil]
        )

      assert Exception.message(error) ==
               "localize requires at least year, month, day. Found year: 2026, month: nil, day: nil"
    end

    test "message with a single field" do
      error =
        Calendrical.MissingFieldsError.exception(
          function: "week_of_year",
          fields: [year: nil]
        )

      assert Exception.message(error) == "week_of_year requires at least year. Found year: nil"
    end

    test "raising the exception" do
      assert_raise Calendrical.MissingFieldsError,
                   "month_of_year requires at least month. Found month: nil",
                   fn ->
                     raise Calendrical.MissingFieldsError,
                       function: "month_of_year",
                       fields: [month: nil]
                   end
    end
  end
end
