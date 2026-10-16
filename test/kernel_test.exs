defmodule Calendrical.Kernel.Test do
  @moduledoc """
  The kernel callbacks every calendar answers: a leap month's position,
  and the figures a date is written with and the date they name.

  """

  use ExUnit.Case, async: true

  {:ok, modules} = :application.get_key(:calendrical, :modules)

  @calendars for module <- Enum.sort(modules),
                 Code.ensure_loaded?(module),
                 function_exported?(module, :valid_date?, 3),
                 function_exported?(module, :naive_datetime_from_iso_days, 1),
                 do: module

  for calendar <- @calendars do
    describe "#{inspect(calendar)}" do
      setup do
        {:ok, date: Date.convert!(~D[2025-06-15], unquote(calendar)), calendar: unquote(calendar)}
      end

      test "a written date names the date it was written for", %{date: date, calendar: calendar} do
        {year, month, day} = calendar.written_date(date.year, date.month, date.day)
        assert is_integer(year) and is_integer(day)
        assert is_integer(month) or match?({m, :leap} when is_integer(m), month)

        assert calendar.date_from_written_date(year, month, day) ==
                 {:ok, {date.year, date.month, date.day}}
      end

      test "the leap month is the position named {_, :leap}", %{date: date, calendar: calendar} do
        leap_month = calendar.leap_month(date.year)
        traditional_months = calendar.traditional_months(date.year)

        case Enum.find_index(traditional_months, &match?({_month, :leap}, &1)) do
          nil -> assert is_nil(leap_month)
          index -> assert leap_month == index + 1
        end
      end
    end
  end

  test "a Hebrew date is written as its own fields, its leap month at position 6" do
    assert Calendrical.Hebrew.written_date(5786, 7, 15) == {5786, 7, 15}
    assert Calendrical.Hebrew.written_date(5787, 8, 15) == {5787, 8, 15}
    assert Calendrical.Hebrew.date_from_written_date(5786, 7, 15) == {:ok, {5786, 7, 15}}
    assert Calendrical.Hebrew.date_from_written_date(5786, 13, 1) == {:error, :invalid_date}
    assert Calendrical.Hebrew.leap_month(5787) == 6
    assert Calendrical.Hebrew.leap_month(5786) == nil
  end

  test "a lunisolar date is written with its traditional month" do
    assert Calendrical.Chinese.written_date(4660, 3, 1) == {4660, {2, :leap}, 1}
    assert Calendrical.Chinese.written_date(4660, 4, 1) == {4660, 3, 1}
    assert Calendrical.Chinese.date_from_written_date(4660, {2, :leap}, 1) == {:ok, {4660, 3, 1}}
    assert Calendrical.Chinese.date_from_written_date(4660, 3, 1) == {:ok, {4660, 4, 1}}

    assert Calendrical.Chinese.date_from_written_date(4661, {2, :leap}, 1) ==
             {:error, :invalid_date}

    assert Calendrical.Chinese.leap_month(4660) == 3
  end

  test "a shifted year is written as the base calendar's date" do
    assert Calendrical.Julian.March25.written_date(1750, 1, 1) == {1750, 3, 25}
    assert Calendrical.Julian.March25.date_from_written_date(1750, 3, 25) == {:ok, {1750, 1, 1}}

    {:ok, us} = Calendrical.FiscalYear.calendar_for(:US)
    assert us.written_date(2026, 1, 31) == {2025, 10, 31}
    assert us.date_from_written_date(2025, 10, 31) == {:ok, {2026, 1, 31}}
  end
end
