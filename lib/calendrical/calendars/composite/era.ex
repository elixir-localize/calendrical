defmodule Calendrical.Composite.Era do
  @moduledoc false

  # The days of an era in a composite calendar.
  #
  # A member calendar counts an era's days from its own first day of the
  # era, which is not another's: the Julian and the Gregorian calendar
  # begin the common era two days apart, and a Julian year reckoned from
  # 25 March begins it 83 days after one reckoned from 1 January. A
  # composite keeps one count through every change of calendar an era
  # runs through. An era counted on from its first day is counted as the
  # earliest calendar it runs through counts it, and one counted back
  # from its last day as the latest does: the count on that calendar's
  # own nearest day, and the days from there.
  #
  # `segments` are the composite's segments in order, as
  # `Calendrical.Composite.Config.segments/1` returns them, and `index`
  # is the place among them of the segment the date is in.

  @doc false
  def day_of_era(segments, index, year, month, day) do
    %{calendar: calendar} = Enum.at(segments, index)

    case calendar.day_of_era(year, month, day) do
      {count, era} when is_integer(count) and is_integer(era) ->
        {count_of_era(segments, index, {year, month, day}, count, era), era}

      other ->
        other
    end
  end

  # Where the era runs through no change of calendar at either end of the
  # date's segment, the calendar's own count stands and nothing more is
  # asked.
  defp count_of_era(segments, index, {year, month, day}, count, era) do
    back = if index > 0, do: era_through_change(segments, index, era)
    on = if index < length(segments) - 1, do: era_through_change(segments, index + 1, era)

    if is_nil(back) and is_nil(on) do
      count
    else
      %{calendar: calendar} = segment = Enum.at(segments, index)
      iso_days = calendar.date_to_iso_days(year, month, day)

      if counts_on?(calendar, segment, iso_days, count, era),
        do: counted_on(back, segments, index, era, iso_days, count),
        else: counted_back(on, segments, index, era, iso_days, count)
    end
  end

  # A day of an era counted on from its first day: the count on the last
  # day of the earliest segment the era runs back through, and the days
  # since. The calendar's own count where the era begins in its segment.
  defp counted_on(nil, _segments, _index, _era, _iso_days, count), do: count

  defp counted_on(
         {last, count_on_last, _first, _count_on_first},
         segments,
         index,
         era,
         iso_days,
         _count
       ) do
    {last, count_on_last} = era_start(segments, index - 1, era, {last, count_on_last})
    count_on_last + iso_days - last
  end

  # A day of an era counted back from its last day: the count on the
  # first day of the latest segment the era runs on through, and the days
  # to it. The calendar's own count where the era ends in its segment.
  defp counted_back(nil, _segments, _index, _era, _iso_days, count), do: count

  defp counted_back(
         {_last, _count_on_last, first, count_on_first},
         segments,
         index,
         era,
         iso_days,
         _count
       ) do
    {first, count_on_first} = era_end(segments, index + 1, era, {first, count_on_first})
    count_on_first + first - iso_days
  end

  # The last day of the earliest segment the era runs back through from
  # the segment at `index`, and its calendar's count on that day, or
  # `reached` when the era does not run back through the change of
  # calendar the segment begins with.
  defp era_start(_segments, 0, _era, reached), do: reached

  defp era_start(segments, index, era, reached) do
    case era_through_change(segments, index, era) do
      {last, count_on_last, _first, _count_on_first} ->
        era_start(segments, index - 1, era, {last, count_on_last})

      nil ->
        reached
    end
  end

  # The first day of the latest segment the era runs on through from the
  # segment at `index`, and its calendar's count on that day.
  defp era_end(segments, index, _era, reached) when index >= length(segments) - 1, do: reached

  defp era_end(segments, index, era, reached) do
    case era_through_change(segments, index + 1, era) do
      {_last, _count_on_last, first, count_on_first} ->
        era_end(segments, index + 1, era, {first, count_on_first})

      nil ->
        reached
    end
  end

  # An era runs through the change of calendar that begins the segment at
  # `index` when the calendars either side of it name their eras from the
  # same CLDR calendar and both give that era: the old calendar on its
  # last day and the new one on its first. Each is asked only about a day
  # of its own, the new calendar first, since an era that began after the
  # change is the usual case and the old calendar need not then be asked.
  defp era_through_change(segments, index, era) do
    %{calendar: old, last: last} = Enum.at(segments, index - 1)
    %{calendar: new, first: first} = Enum.at(segments, index)

    with true <- old.era_calendar_type() == new.era_calendar_type(),
         {count_on_first, ^era} <- member_day_of_era(new, first),
         {count_on_last, ^era} <- member_day_of_era(old, last) do
      {last, count_on_last, first, count_on_first}
    else
      _another_era -> nil
    end
  end

  # Whether the calendar counts the era's days on from its first day, as
  # most are counted, or back from its last, as the years before the
  # common era are. The count on a neighbouring day of the era says
  # which: the neighbour in the calendar's own segment where it has one,
  # and the other where that one is a day of another era.
  defp counts_on?(calendar, %{last: last}, iso_days, count, era) do
    {near, far} = if is_nil(last) or iso_days < last, do: {1, -1}, else: {-1, 1}

    case member_day_of_era(calendar, iso_days + near) do
      {neighbour, ^era} ->
        (neighbour - count) * near > 0

      _another_era ->
        not match?(
          {neighbour, ^era} when (neighbour - count) * far < 0,
          member_day_of_era(calendar, iso_days + far)
        )
    end
  end

  defp member_day_of_era(calendar, iso_days) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    calendar.day_of_era(year, month, day)
  end
end
