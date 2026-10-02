defmodule Calendrical.Composite.Label do
  @moduledoc false

  # The segment of a composite calendar that a date's year, month and day
  # are read in.
  #
  # A date is read where it falls among the changes of calendar: in the
  # segment of the last change whose first day's year, month and day it is
  # not before. That is the order of the days themselves while a calendar's
  # months follow one another through its year. A calendar whose year
  # turns after its first month, a Julian year reckoned from 25 March or
  # from 1 September, has days whose month and day come before those of
  # the day it took effect on: 1 September 1492 began Russia's year 1493,
  # and that year's January to August fall, by their order, before its
  # September, in the calendar before. So where the segment a date falls
  # in has no day of the date's year, the date is read in a segment that
  # has: one whose calendar has the date on a day of its own, or failing
  # that the first to have the year.
  #
  # Where the segment a date falls in has days of the date's year, the
  # date is read there, though a later segment has that year too: 1
  # January to 24 March 1155 are England's days before its year turned on
  # 25 March, and 1 January to 24 March 1156, which carry the same year,
  # have no dates of their own, 29 February among them.
  #
  # `segments` are the composite's segments in order, as
  # `Calendrical.Composite.Config.segments/1` returns them, and `index` is
  # the place among them that the date falls at by its order.

  @doc false
  def segment(segments, index, year, month, day) do
    if has_year?(Enum.at(segments, index), year) do
      index
    else
      with_year =
        for {segment, place} <- Enum.with_index(segments), has_year?(segment, year) do
          {segment, place}
        end

      holder =
        Enum.find(with_year, fn {segment, _place} -> has_date?(segment, year, month, day) end)

      case holder || List.first(with_year) do
        {_segment, place} -> place
        nil -> index
      end
    end
  end

  # A calendar's years follow one another, so the years of a segment's
  # days run from that of its first day to that of its last. The first
  # segment has no first day and the last has no last.
  defp has_year?(%{first_year: first_year, last_year: last_year}, year) do
    (is_nil(first_year) or year >= first_year) and (is_nil(last_year) or year <= last_year)
  end

  defp has_date?(%{calendar: calendar, first: first, last: last}, year, month, day) do
    calendar.valid_date?(year, month, day) and
      within?(calendar.date_to_iso_days(year, month, day), first, last)
  end

  defp within?(iso_days, first, last) do
    (is_nil(first) or iso_days >= first) and (is_nil(last) or iso_days <= last)
  end
end
