defmodule Calendrical.PeriodSequenceTest do
  use ExUnit.Case, async: true

  defmodule C454 do
    use Calendrical.Base.Week,
      day_of_week: 7,
      first_or_last: :first,
      min_days_in_first_week: 7,
      month_of_year: 2,
      weeks_in_month: [4, 5, 4]
  end

  defmodule C544 do
    use Calendrical.Base.Week,
      day_of_week: 1,
      first_or_last: :first,
      min_days_in_first_week: 7,
      month_of_year: 1,
      weeks_in_month: [5, 4, 4]
  end

  for calendar <- [C454, C544] do
    test "an ascending sequence of quarters in #{inspect(calendar)} follow each other" do
      {:ok, d} = Date.new(1900, 1, 1, unquote(calendar))
      m = Calendrical.Interval.quarter(d)

      Enum.reduce(1..5000, m, fn _i, m ->
        m2 = Calendrical.next(m, :quarter, coerce: true)

        assert Calendrical.date_to_iso_days(m.last) + 1 ==
                 Calendrical.date_to_iso_days(m2.first)

        m2
      end)
    end

    test "an ascending sequence of months in #{inspect(calendar)} follow each other" do
      {:ok, d} = Date.new(1900, 1, 1, unquote(calendar))
      m = Calendrical.Interval.month(d)

      Enum.reduce(1..5000, m, fn _i, m ->
        m2 = Calendrical.next(m, :month, coerce: true)

        assert Calendrical.date_to_iso_days(m.last) + 1 ==
                 Calendrical.date_to_iso_days(m2.first)

        m2
      end)
    end

    test "an ascending sequence of weeks in #{inspect(calendar)} follow each other" do
      {:ok, d} = Date.new(1900, 1, 1, unquote(calendar))
      m = Calendrical.Interval.week(d)

      Enum.reduce(1..5000, m, fn _i, m ->
        m2 = Calendrical.next(m, :week, coerce: true)

        assert Calendrical.date_to_iso_days(m.last) + 1 ==
                 Calendrical.date_to_iso_days(m2.first)

        m2
      end)
    end

    test "a descending sequence of quarters in #{inspect(calendar)} follow each other" do
      {:ok, d} = Date.new(2050, 1, 1, unquote(calendar))
      m = Calendrical.Interval.quarter(d)

      Enum.reduce(1..5000, m, fn _i, m ->
        m2 = Calendrical.previous(m, :quarter, coerce: true)

        assert Calendrical.date_to_iso_days(m2.last) + 1 ==
                 Calendrical.date_to_iso_days(m.first)

        m2
      end)
    end

    test "a descending sequence of months in #{inspect(calendar)} follow each other" do
      {:ok, d} = Date.new(2050, 1, 1, unquote(calendar))
      m = Calendrical.Interval.month(d)

      Enum.reduce(1..5000, m, fn _i, m ->
        m2 = Calendrical.previous(m, :month, coerce: true)

        assert Calendrical.date_to_iso_days(m2.last) + 1 ==
                 Calendrical.date_to_iso_days(m.first)

        m2
      end)
    end

    test "a descending sequence of weeks in #{inspect(calendar)} follow each other" do
      {:ok, d} = Date.new(2050, 1, 1, unquote(calendar))
      m = Calendrical.Interval.week(d)

      Enum.reduce(1..5000, m, fn _i, m ->
        m2 = Calendrical.previous(m, :week, coerce: true)

        assert Calendrical.date_to_iso_days(m2.last) + 1 ==
                 Calendrical.date_to_iso_days(m.first)

        m2
      end)
    end
  end
end
