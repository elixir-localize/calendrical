defmodule Calendrical.CompositeDatelessDaysTest do
  @moduledoc """
  Where two stretches of a composite's days carry the same labels, one has
  no dates of its own, and a shift or a conversion that reaches one of its
  days answers the first later day that has a date (user, 2026-10-03), as a
  shift into the days a reform took out answers the day after them.

  When the day a year begins on moves, the incoming calendar's label year
  owns its whole counted year, so the outgoing calendar's last stretch is
  the dateless one. England's 1 January to 24 March 1155, which the January
  reckoning had called 1155, are claimed by the Lady Day year 1155 and are
  written as its first day, 25 March 1155. Russia's 1 September to 31
  December 1699, which began the September year 1700, are claimed by Peter
  the Great's January year 1700 and are written as 1 January 1700.

  Every day about every change of every composite is checked: its member
  calendar's date, when it reads back as the day, and otherwise the date of
  the first later day whose member date does.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Reform.{England, Japan, Sweden}
  alias Calendrical.Russia

  test "England's January to 24 March 1155" do
    # A year on from the base's 15 February 1154 reaches the dateless
    # stretch and answers the Lady Day year's first day.
    assert Date.shift(~D[1154-02-15 Calendrical.Reform.England], year: 1) ==
             ~D[1155-01-01 Calendrical.Reform.England]

    assert Date.convert(~D[1155-01-15 Calendrical.Julian], England) ==
             {:ok, ~D[1155-01-01 Calendrical.Reform.England]}

    assert Date.convert(~D[1155-03-24 Calendrical.Julian], England) ==
             {:ok, ~D[1155-01-01 Calendrical.Reform.England]}

    # The day before the stretch keeps its own date, and the days the
    # old model left dateless — the Julian January to 24 March 1156 —
    # are the Lady Day year 1155's months 11 to 13.
    assert Date.convert(~D[1154-12-31 Calendrical.Julian], England) ==
             {:ok, ~D[1154-12-31 Calendrical.Reform.England]}

    assert Date.convert(~D[1156-01-15 Calendrical.Julian], England) ==
             {:ok, ~D[1155-11-15 Calendrical.Reform.England]}
  end

  test "Russia's September to December 1699" do
    # A month on from the September year 1699's last month reaches the
    # dateless stretch and answers the January year 1700's first day.
    assert Date.shift(~D[1699-12-15 Calendrical.Russia], month: 1) ==
             ~D[1700-01-01 Calendrical.Russia]

    assert Date.convert(~D[1699-12-31 Calendrical.Julian], Russia) ==
             {:ok, ~D[1700-01-01 Calendrical.Russia]}

    assert Date.convert(~D[1700-09-01 Calendrical.Julian], Russia) ==
             {:ok, ~D[1700-09-01 Calendrical.Russia]}
  end

  test "a shift into the days a reform took out answers the day after them" do
    assert Date.shift(~D[1752-08-05 Calendrical.Reform.England], month: 1) ==
             ~D[1752-09-14 Calendrical.Reform.England]
  end

  test "every day about a change is its own date or the next day's that has one" do
    for calendar <- composites() do
      reach = if calendar == Japan, do: 60, else: 800

      for change <- changes(calendar), iso_days <- (change - reach)..(change + reach) do
        assert calendar.date_from_iso_days(iso_days) == expected(calendar, iso_days),
               "#{inspect(calendar)} day #{iso_days}"
      end
    end
  end

  defp expected(calendar, iso_days) do
    date = calendar.calendar_for_iso_days(iso_days).date_from_iso_days(iso_days)
    {year, month, day} = date

    if calendar.date_to_iso_days(year, month, day) == iso_days,
      do: date,
      else: expected(calendar, iso_days + 1)
  end

  defp changes(calendar) do
    calendar.__config__() |> Enum.drop(1) |> Enum.map(&elem(&1, 0))
  end

  defp composites do
    reforms =
      for {territory, _reform} <- Calendrical.Reform.reforms(),
          {:ok, calendar} <- [Calendrical.Reform.calendar_for(territory)],
          do: calendar

    Enum.uniq([England, Sweden, Japan, Russia | reforms])
  end
end
