defmodule Calendrical.Base.MonthWeeks do
  @moduledoc false

  # The weeks of a month: how many it has (`weeks_in_month/2`) and the days
  # of its nth week (`month_week/3`), which every calendar answers through
  # `Calendrical.Compiler.StandardCallbacks`.
  #
  # The weeks of a month are the weeks the calendar's `week_of_month/3`
  # names for it: week 1 is the month's first week under the calendar's
  # week configuration, which may begin in the month before, and the last
  # week may run into the month after. `week_of_month/3` is the authority
  # on which week a day is in; the walks here are bounded by the days in a
  # week.

  # The number of weeks in a month, `{:error, :invalid_date}` for a month
  # the year does not have, or `{:error, :not_defined}` where the calendar
  # has no weeks.
  def weeks_in_month(calendar, year, month) do
    with {_first_week_start, _second_week_start, _end_of_weeks, weeks} <-
           month_weeks(calendar, year, month) do
      weeks
    end
  end

  # The days of the nth week of a month, `{:error, :invalid_date}` where the
  # month has no such week, or `{:error, :not_defined}` where the calendar
  # has no weeks.
  def month_week(calendar, year, month, nth) when is_integer(nth) and nth >= 1 do
    with {_first, _second, _end_of_weeks, _weeks} = month_weeks <-
           month_weeks(calendar, year, month) do
      nth_week(nth, month_weeks, calendar)
    end
  end

  def month_week(_calendar, _year, _month, _nth), do: {:error, :invalid_date}

  defp nth_week(nth, {_first, _second, _end_of_weeks, weeks}, _calendar) when nth > weeks do
    {:error, :invalid_date}
  end

  defp nth_week(1, {first_week_start, _second, end_of_weeks, 1}, calendar) do
    iso_days_to_range(first_week_start, end_of_weeks, calendar)
  end

  defp nth_week(1, {first_week_start, second_week_start, _end_of_weeks, _weeks}, calendar) do
    iso_days_to_range(first_week_start, second_week_start - 1, calendar)
  end

  defp nth_week(nth, {_first, second_week_start, end_of_weeks, _weeks}, calendar) do
    days_in_week = calendar.days_in_week()
    first = second_week_start + (nth - 2) * days_in_week
    iso_days_to_range(first, min(first + days_in_week - 1, end_of_weeks), calendar)
  end

  # The month's weeks in iso days: the first day of its week 1, the first
  # day of its week 2, the last day of its last week and the week count.
  # Week 1 may be short when a calendar's weeks do not cross its months, so
  # weeks are blocks of `days_in_week/0` days from the start of week 2, not
  # of week 1.
  defp month_weeks(calendar, year, month) do
    with %Date.Range{first_in_iso_days: first, last_in_iso_days: last} <-
           calendar.month(year, month) do
      case week_of_month(first, calendar) do
        {:error, _reason} = error ->
          error

        {_month, _week} ->
          days_in_week = calendar.days_in_week()
          first_week_start = start_of_first_week(first, month, days_in_week, calendar)
          {end_of_weeks, weeks} = end_of_last_week(last, month, days_in_week, calendar)
          second_week_start = start_of_second_week(first_week_start, month, weeks, calendar)
          {first_week_start, second_week_start, end_of_weeks, weeks}
      end
    end
  end

  defp start_of_second_week(_first_week_start, _month, 1 = _weeks, _calendar), do: nil

  defp start_of_second_week(first_week_start, month, _weeks, calendar) do
    first_not_in_week_1 =
      Enum.find(
        (first_week_start + 1)..(first_week_start + calendar.days_in_week())//1,
        &(week_of_month(&1, calendar) != {month, 1})
      )

    {^month, 2} = week_of_month(first_not_in_week_1, calendar)
    first_not_in_week_1
  end

  defp week_of_month(iso_days, calendar) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    calendar.week_of_month(year, month, day)
  end

  # The first day of the month's week 1. When the month's first day is
  # already in week 1 that week may have begun in the month before, so
  # walk back through its days; otherwise the first day belongs to the
  # month before's last week and week 1 begins within the first week of
  # days.
  defp start_of_first_week(first, month, days_in_week, calendar) do
    if week_of_month(first, calendar) == {month, 1} do
      back_to_start_of_week(first, month, first - days_in_week + 1, calendar)
    else
      Enum.find(
        (first + 1)..(first + days_in_week - 1)//1,
        &(week_of_month(&1, calendar) == {month, 1})
      )
    end
  end

  defp back_to_start_of_week(iso_days, month, floor, calendar) do
    if iso_days > floor and week_of_month(iso_days - 1, calendar) == {month, 1} do
      back_to_start_of_week(iso_days - 1, month, floor, calendar)
    else
      iso_days
    end
  end

  # The last day of the month's last week and the week count. When the
  # month's last day is in one of its own weeks that week may run into
  # the month after, so walk forward through its days; otherwise the
  # last day belongs to the month after's week 1, and the month's last
  # week ends within the last week of days.
  defp end_of_last_week(last, month, days_in_week, calendar) do
    case week_of_month(last, calendar) do
      {^month, weeks} ->
        {forward_to_end_of_week(last, month, weeks, last + days_in_week - 1, calendar), weeks}

      {_other_month, _week} ->
        (last - 1)..(last - days_in_week + 1)//-1
        |> Enum.find(&match?({^month, _week}, week_of_month(&1, calendar)))
        |> then(fn end_of_weeks ->
          {^month, weeks} = week_of_month(end_of_weeks, calendar)
          {end_of_weeks, weeks}
        end)
    end
  end

  defp forward_to_end_of_week(iso_days, month, weeks, ceiling, calendar) do
    if iso_days < ceiling and week_of_month(iso_days + 1, calendar) == {month, weeks} do
      forward_to_end_of_week(iso_days + 1, month, weeks, ceiling, calendar)
    else
      iso_days
    end
  end

  defp iso_days_to_range(first, last, calendar) do
    {first_year, first_month, first_day} = calendar.date_from_iso_days(first)
    {last_year, last_month, last_day} = calendar.date_from_iso_days(last)

    with {:ok, first_date} <- Date.new(first_year, first_month, first_day, calendar),
         {:ok, last_date} <- Date.new(last_year, last_month, last_day, calendar) do
      Date.range(first_date, last_date)
    end
  end
end
