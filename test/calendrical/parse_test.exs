defmodule Calendrical.ParseTest do
  use ExUnit.Case, async: true

  doctest Calendrical, only: [parse: 2]

  describe "Calendrical.parse/2 — dispatch" do
    test "ISO date returns a Date" do
      assert {:ok, ~D[2026-05-16]} = Calendrical.parse("2026-05-16", locale: :en)
    end

    test "locale-formatted date returns a Date" do
      assert {:ok, ~D[2026-05-16]} = Calendrical.parse("5/16/26", locale: :en)
    end

    test "ISO time returns a Time" do
      assert {:ok, ~T[14:30:00]} = Calendrical.parse("14:30:00", locale: :en)
    end

    test "12-hour time returns a Time" do
      assert {:ok, ~T[14:30:00]} = Calendrical.parse("2:30 PM", locale: :en)
    end

    test "ISO datetime returns a NaiveDateTime" do
      assert {:ok, ~N[2026-05-16 14:30:00]} =
               Calendrical.parse("2026-05-16T14:30:00", locale: :en)
    end

    test "locale-formatted datetime returns a NaiveDateTime" do
      assert {:ok, ~N[2026-05-16 14:30:00]} =
               Calendrical.parse("May 16, 2026, 2:30 PM", locale: :en)
    end

    test "ISO datetime with Z offset returns a DateTime" do
      assert {:ok, %DateTime{}} =
               Calendrical.parse("2026-05-16T14:30:00Z", locale: :en)
    end

    test "ISO range returns a Date.Range" do
      assert {:ok, %Date.Range{} = range} =
               Calendrical.parse("2026-05-05 – 2026-05-10", locale: :en)

      assert range.first == ~D[2026-05-05]
      assert range.last == ~D[2026-05-10]
    end

    test "locale-formatted range returns a Date.Range" do
      assert {:ok, %Date.Range{} = range} =
               Calendrical.parse("May 5, 2026 – May 10, 2026", locale: :en)

      assert range.first == ~D[2026-05-05]
      assert range.last == ~D[2026-05-10]
    end

    test "range with 'to' separator returns a Date.Range" do
      assert {:ok, %Date.Range{} = range} =
               Calendrical.parse("May 5, 2026 to May 10, 2026", locale: :en)

      assert range.first == ~D[2026-05-05]
      assert range.last == ~D[2026-05-10]
    end
  end

  describe "Calendrical.parse/2 — calendar option" do
    test "Hebrew date" do
      assert {:ok, %Date{calendar: Calendrical.Hebrew}} =
               Calendrical.parse("2026-05-16", locale: :en, calendar: :hebrew)
    end

    test "Buddhist interval preserves calendar in Date.Range endpoints" do
      assert {:ok, %Date.Range{} = range} =
               Calendrical.parse("2026-05-05 – 2026-05-10",
                 locale: :en,
                 calendar: :buddhist
               )

      assert range.first.calendar == Calendrical.Buddhist
      assert range.last.calendar == Calendrical.Buddhist
    end

    test "calendar option accepts a module — Calendrical.Hebrew" do
      assert {:ok, %Date{calendar: Calendrical.Hebrew}} =
               Calendrical.parse("2026-05-16", locale: :en, calendar: Calendrical.Hebrew)
    end

    test "calendar option accepts Calendar.ISO as alias for :gregorian" do
      assert {:ok, ~D[2026-05-16]} =
               Calendrical.parse("2026-05-16", locale: :en, calendar: Calendar.ISO)
    end

    test "module-form calendar works for intervals" do
      assert {:ok, %Date.Range{} = range} =
               Calendrical.parse("2026-05-05 – 2026-05-10",
                 locale: :en,
                 calendar: Calendrical.Buddhist
               )

      assert range.first.calendar == Calendrical.Buddhist
      assert range.last.calendar == Calendrical.Buddhist
    end
  end

  describe "Calendrical.parse/2 — order: date before time" do
    test "an ambiguous bare 4-digit number doesn't get classified as a time" do
      # If "2026" were parseable as a time, time would never run
      # because date is tried first. Neither parser should match
      # this — it's not a valid date or time on its own — but we
      # still verify the dispatch order doesn't surface a stale
      # time interpretation.
      assert {:error, %Calendrical.ParseError{}} =
               Calendrical.parse("2026", locale: :en)
    end
  end

  describe "Calendrical.parse/2 — errors" do
    test "garbage input returns ParseError with attempts" do
      assert {:error, %Calendrical.ParseError{} = err} =
               Calendrical.parse("garbage", locale: :en)

      assert err.input == "garbage"
      assert err.locale == :en

      # attempts must include each sub-parser actually run.
      # interval is skipped (no separator), so we expect date,
      # time, datetime in order.
      kinds = Enum.map(err.attempts, &elem(&1, 0))
      assert kinds == [:date, :time, :datetime]

      assert Enum.all?(err.attempts, fn {_kind, ex} -> is_exception(ex) end)
    end

    test "interval-shaped input that fails sub-parse still falls through to other parsers" do
      # Has an interval-shaped separator but neither half is a
      # parseable date. The interval attempt fails; we then fall
      # through. None of the other sub-parsers can match a
      # bidi-separated garbage string either, so we get a
      # ParseError.
      assert {:error, %Calendrical.ParseError{attempts: attempts}} =
               Calendrical.parse("foo – bar", locale: :en)

      kinds = Enum.map(attempts, &elem(&1, 0))
      assert :interval in kinds
    end

    test "empty input returns a ParseError" do
      assert {:error, %Calendrical.ParseError{}} = Calendrical.parse("", locale: :en)
    end
  end

  describe "Calendrical.parse/2 — exceptions are structured" do
    test "ParseError carries no :message struct field; message/1 materializes it" do
      assert {:error, %Calendrical.ParseError{} = err} =
               Calendrical.parse("garbage", locale: :en)

      refute Map.has_key?(err, :message)
      msg = Exception.message(err)
      assert msg =~ "garbage"
      assert msg =~ ":en"
    end

    test "DateParseError carries no :message field" do
      assert {:error, %Calendrical.DateParseError{} = err} =
               Calendrical.Date.parse("garbage", locale: :en)

      refute Map.has_key?(err, :message)
      assert Exception.message(err) =~ "garbage"
    end

    test "DateRangeParseError :inverted carries :from and :to, not prose" do
      assert {:error, %Calendrical.DateRangeParseError{} = err} =
               Calendrical.Date.parse_range({"2026-05-10", "2026-05-05"}, locale: :en)

      assert err.reason == :inverted
      assert err.from == ~D[2026-05-10]
      assert err.to == ~D[2026-05-05]
      refute Map.has_key?(err, :message)
    end

    test "DateRangeParseError reason_atoms/0 is exhaustive" do
      assert Calendrical.DateRangeParseError.reason_atoms() == [
               :no_separator,
               :inverted,
               :from_parse_failed,
               :to_parse_failed
             ]
    end
  end

  describe "Calendrical.parse/2 — as: :map" do
    test "dispatches partial date through to a field map" do
      assert {:ok, %{calendar: Calendar.ISO, month: 5, day: 5}} =
               Calendrical.parse("May 5", locale: :en, as: :map)
    end

    test "dispatches partial time through to a field map" do
      assert {:ok, %{hour: 11, minute: 30}} =
               Calendrical.parse("11:30", locale: :en, as: :map)
    end

    test "dispatches range through to a map pair" do
      assert {:ok,
              {%{calendar: Calendar.ISO, year: 2026, month: 5, day: 5},
               %{calendar: Calendar.ISO, year: 2026, month: 5, day: 10}}} =
               Calendrical.parse("May 5 – May 10, 2026", locale: :en, as: :map)
    end
  end
end
