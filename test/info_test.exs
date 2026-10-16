defmodule Calendrical.Info.Test do
  @moduledoc """
  Every calendar module answers `info/0` with the static facts about
  itself, and the facts agree with the callbacks that still answer them.

  """

  use ExUnit.Case, async: true

  {:ok, modules} = :application.get_key(:calendrical, :modules)

  @calendars for module <- Enum.sort(modules),
                 Code.ensure_loaded?(module),
                 function_exported?(module, :valid_date?, 3),
                 function_exported?(module, :naive_datetime_from_iso_days, 1),
                 do: module

  @week_days [1, 2, 3, 4, 5, 6, 7, :first_day_of_year]

  for calendar <- @calendars do
    describe "#{inspect(calendar)}" do
      test "info/0 answers the facts about the calendar" do
        calendar = unquote(calendar)
        info = calendar.info()

        assert %Calendrical.Info{calendar: ^calendar} = info
        assert info.cldr_calendar_type == calendar.cldr_calendar_type()
        assert info.era_calendar_type == calendar.era_calendar_type()
        assert info.parsing_calendar == calendar.parsing_calendar()
        assert info.structure == expected_structure(calendar)
        assert is_boolean(info.year_zero?)
        assert is_nil(info.epoch) or is_integer(info.epoch)

        assert {fewest, most} = info.months_in_year
        assert is_integer(fewest) and is_integer(most) and fewest <= most

        assert %{first_day: first_day, min_days_in_first_week: min_days} = info.weeks
        assert first_day in @week_days
        assert min_days in 1..7

        assert info.years_in_cycle == expected_cycle(calendar)
        assert is_nil(info.year_cycle) or is_integer(info.year_cycle)
        assert is_nil(info.location) or is_function(info.location, 1)
        assert is_nil(info.month_lengths) or is_map(info.month_lengths)
      end
    end
  end

  # The calendar is a variable here, so the answer's shape is not known
  # from the module's own definition.
  defp expected_cycle(calendar) do
    case calendar.years_in_cycle() do
      {:error, :undefined} -> nil
      years -> years
    end
  end

  defp expected_structure(calendar) do
    case calendar.calendar_base() do
      :week -> :weeks
      :month -> :months
    end
  end

  test "a Behaviour calendar's epoch is its epoch/0" do
    assert Calendrical.Hebrew.info().epoch == Calendrical.Hebrew.epoch()
    assert Calendrical.Persian.info().epoch == Calendrical.Persian.epoch()
  end

  test "the lunisolar calendars state their cycle and their place" do
    for calendar <- [
          Calendrical.Chinese,
          Calendrical.Korean,
          Calendrical.Vietnamese,
          Calendrical.LunarJapanese
        ] do
      info = calendar.info()
      assert info.year_cycle == 60
      assert is_function(info.location, 1)

      assert info.location.(Calendrical.Gregorian.date_to_iso_days(2026, 1, 1)) ==
               calendar.location(Calendrical.Gregorian.date_to_iso_days(2026, 1, 1))
    end
  end

  test "the Julian calendars and Sweden's transitional calendar have no year 0" do
    for calendar <- [
          Calendrical.Julian,
          Calendrical.Julian.March25,
          Calendrical.Reform.Sweden.Transitional,
          Calendrical.Reform.England
        ] do
      refute calendar.info().year_zero?
    end

    assert Calendrical.Gregorian.info().year_zero?
  end

  test "a composite calendar lists its members from the base" do
    assert [{nil, Calendrical.Julian} | changes] = Calendrical.Reform.England.info().members

    assert [
             {_, Calendrical.Julian.March25},
             {_, Calendrical.Julian.Jan1},
             {_, Calendrical.Gregorian}
           ] = changes

    assert Enum.all?(changes, fn {first, _calendar} -> is_integer(first) end)
  end

  test "month lengths are gathered from days_in_month/1" do
    assert %{1 => 31, 2 => 28..29//1} = Calendrical.Gregorian.info().month_lengths
    assert %{1 => 30, 4 => 29, 2 => 29..30//1} = Calendrical.Hebrew.info().month_lengths
    assert is_nil(Calendrical.Reform.England.info().month_lengths)
  end
end
