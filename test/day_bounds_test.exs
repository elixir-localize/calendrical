defmodule Calendrical.DayBoundsTest do
  use ExUnit.Case, async: true

  # `day_bounds/1` is the inverse of `date_at/2` with `day_start: :sunset`, at
  # the calendar's own place: a day is the half-open span from the sunset of
  # the evening before to its own, and the next begins where it ends.

  @calendars [
    Calendrical.Hebrew,
    Calendrical.Islamic.UmmAlQura,
    Calendrical.Islamic.Rgsa,
    Calendrical.Islamic.Observational
  ]

  defp days(calendar, from, count) do
    for offset <- 0..(count - 1) do
      {:ok, date} = Date.convert(Date.add(from, offset), calendar)
      date
    end
  end

  describe "the inverse of date_at/2 with day_start: :sunset" do
    for calendar <- @calendars do
      @calendar calendar

      test "#{inspect(calendar)}: the start is the day, the instant before it the day before" do
        for date <- days(@calendar, ~D[2025-12-20], 45) do
          {:ok, {start, stop}} = @calendar.day_bounds(date)

          {:ok, previous} =
            Date.convert(Date.add(Date.convert!(date, Calendar.ISO), -1), @calendar)

          {:ok, next} = Date.convert(Date.add(Date.convert!(date, Calendar.ISO), 1), @calendar)

          assert @calendar.date_at(start, day_start: :sunset) == {:ok, date}

          assert @calendar.date_at(DateTime.add(start, -1, :second), day_start: :sunset) ==
                   {:ok, previous}

          assert @calendar.date_at(DateTime.add(stop, -1, :second), day_start: :sunset) ==
                   {:ok, date}

          assert @calendar.date_at(stop, day_start: :sunset) == {:ok, next}
        end
      end

      test "#{inspect(calendar)}: each day ends where the next begins" do
        bounds =
          for date <- days(@calendar, ~D[2026-03-20], 20) do
            {:ok, bounds} = @calendar.day_bounds(date)
            bounds
          end

        for {{_start, stop}, {next_start, _next_stop}} <- Enum.zip(bounds, tl(bounds)) do
          assert stop == next_start
        end
      end
    end
  end

  describe "the calendar's own place" do
    test "a Hebrew day begins at Jerusalem's sunset, an Islamic day at Mecca's or Cairo's" do
      {:ok, passover} = Date.convert(~D[2026-04-02], Calendrical.Hebrew)
      {:ok, {start, _stop}} = Calendrical.Hebrew.day_bounds(passover)

      # Sunset in Jerusalem on 1 April 2026 is a little before 19:00, 16:00 UTC.
      assert start.hour == 15 and start.minute in 55..59

      {:ok, umm_al_qura} = Date.convert(~D[2025-03-30], Calendrical.Islamic.UmmAlQura)
      {:ok, observational} = Date.convert(~D[2025-03-30], Calendrical.Islamic.Observational)
      {:ok, {mecca, _}} = Calendrical.Islamic.UmmAlQura.day_bounds(umm_al_qura)
      {:ok, {cairo, _}} = Calendrical.Islamic.Observational.day_bounds(observational)

      # Cairo lies west of Mecca, so its sun sets later.
      assert DateTime.compare(cairo, mecca) == :gt
    end
  end

  describe "what has no bounds" do
    test "a date of another calendar" do
      for calendar <- @calendars do
        assert {:error, %Calendrical.IncompatibleCalendarError{from: Calendar.ISO, to: ^calendar}} =
                 calendar.day_bounds(~D[2026-04-02])
      end
    end

    test "a value that is no date" do
      assert {:error, %Calendrical.IncompatibleCalendarError{from: "2026-04-02"}} =
               Calendrical.Hebrew.day_bounds("2026-04-02")
    end
  end
end
