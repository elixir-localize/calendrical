defmodule Calendrical.Base.Common do
  @moduledoc false

  # Logic shared verbatim by Calendrical.Base.Month and
  # Calendrical.Base.Week, plus the calendar-aligned week numbering
  # every calendar without compiled weeks shares. Only functions whose semantics are
  # identical across their users belong here; unit-specific
  # arithmetic stays in the respective base module. See
  # ARCHITECTURE.md for the division of labour between the layers.

  @days_in_week 7

  # The middle field is the month for month calendars and the week
  # for week calendars. Week calendars store the week number in the
  # %Date{} struct's :month field, because the stdlib Date struct
  # has no :week field.
  defguard is_date(year, month_or_week, day)
           when is_integer(year) and is_integer(month_or_week) and is_integer(day)

  # Maps a calendar year to its era year via the Gregorian year the
  # configuration designates: the :beginning year, the :ending year,
  # or for :majority the year containing most of the calendar year
  # (the beginning year when the year starts in January..June, the
  # ending year otherwise).
  def year_of_era(year, %{year: :ending} = config) when is_integer(year) do
    {_, year} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :beginning} = config) when is_integer(year) do
    {year, _} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority, month_of_year: starts} = config)
      when is_integer(year) and starts <= 6 do
    {year, _} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def year_of_era(year, %{year: :majority} = config) do
    {_, year} = Calendrical.start_end_gregorian_years(year, config)
    Calendar.ISO.year_of_era(year)
  end

  def days_in_week do
    @days_in_week
  end

  def days_in_week(_year, _month_or_week) do
    @days_in_week
  end

  # Calendar-aligned week numbering, which every calendar that does not
  # compile its own weeks shares: weeks run on the calendar's own week
  # boundary (the day its `day_of_week/4` numbers 1) and week 1 is the
  # week containing the first day of the year, so a year that opens
  # mid-week has a short week 1 and one that closes mid-week a short last
  # week. Every date numbers within its own year — no ISO-style spill into
  # the adjacent year's numbering. The year is the calendar's own
  # `year/1`, which need not begin on the first day of its first month (a
  # Julian year counted from 25 March).
  def week_of_year(calendar, year, month, day) when is_date(year, month, day) do
    with true <- calendar.valid_date?(year, month, day),
         {:ok, first, _days_in_year, offset} <- year_frame(calendar, year) do
      day_of_year = calendar.date_to_iso_days(year, month, day) - first + 1
      {year, div(day_of_year - 2 + offset, @days_in_week) + 1}
    else
      _invalid -> {:error, :invalid_date}
    end
  end

  def week_of_year(_calendar, _year, _month, _day), do: {:error, :invalid_date}

  def weeks_in_year(calendar, year) do
    case year_frame(calendar, year) do
      {:ok, _first, days_in_year, offset} ->
        weeks = weeks(days_in_year, offset)
        {weeks, days_in_year + offset - 1 - (weeks - 1) * @days_in_week}

      :error ->
        {:error, :invalid_date}
    end
  end

  # The days of week `week` of `year`: the calendar week holding them,
  # cut to the year.
  def week(calendar, year, week) when is_integer(week) do
    with {:ok, first, days_in_year, offset} <- year_frame(calendar, year),
         true <- week >= 1 and week <= weeks(days_in_year, offset) do
      first_day = first + max((week - 1) * @days_in_week - (offset - 1), 0)
      last_day = min(first + week * @days_in_week - offset, first + days_in_year - 1)

      Date.range(date_from_iso_days(calendar, first_day), date_from_iso_days(calendar, last_day))
    else
      _invalid -> {:error, :invalid_date}
    end
  end

  def week(_calendar, _year, _week), do: {:error, :invalid_date}

  # The weeks of a month, numbered as `week_of_year/4` numbers the weeks of
  # a year: week 1 holds the month's first day and a week turns over on the
  # calendar's own week boundary. Days count from the month's first in ISO
  # days, so a month a calendar reform cuts short counts only its own.
  def week_of_month(calendar, year, month, day) when is_date(year, month, day) do
    with true <- calendar.valid_date?(year, month, day),
         %Date.Range{first: first} <- calendar.month(year, month) do
      first_days = calendar.date_to_iso_days(first.year, first.month, first.day)
      day_of_month = calendar.date_to_iso_days(year, month, day) - first_days + 1

      {first_dow, _first, _last} =
        calendar.day_of_week(first.year, first.month, first.day, :default)

      {month, div(day_of_month - 2 + first_dow, @days_in_week) + 1}
    else
      _invalid -> {:error, :invalid_date}
    end
  end

  def week_of_month(_calendar, _year, _month, _day), do: {:error, :invalid_date}

  # The ISO 8601 week of the day, whichever calendar names it, as a
  # week-based calendar's `iso_week_of_year/3` gives it.
  def iso_week_of_year(calendar, year, month, day) when is_date(year, month, day) do
    if calendar.valid_date?(year, month, day) do
      {year, month, day} =
        year
        |> calendar.date_to_iso_days(month, day)
        |> Calendrical.Gregorian.date_from_iso_days()

      Calendrical.Gregorian.iso_week_of_year(year, month, day)
    else
      {:error, :invalid_date}
    end
  end

  def iso_week_of_year(_calendar, _year, _month, _day), do: {:error, :invalid_date}

  defp weeks(days_in_year, offset), do: div(days_in_year - 2 + offset, @days_in_week) + 1

  # The year's first day in ISO days, its length, and the position of its
  # first day within its (calendar-native) week, 1-based: 1 when the year
  # opens on the week's first day.
  defp year_frame(calendar, year) when is_integer(year) do
    case calendar.year(year) do
      %Date.Range{first: first, last: last} ->
        first_days = calendar.date_to_iso_days(first.year, first.month, first.day)
        last_days = calendar.date_to_iso_days(last.year, last.month, last.day)

        {first_dow, _first, _last} =
          calendar.day_of_week(first.year, first.month, first.day, :default)

        {:ok, first_days, last_days - first_days + 1, first_dow}

      _invalid ->
        :error
    end
  end

  defp year_frame(_calendar, _year), do: :error

  defp date_from_iso_days(calendar, iso_days) do
    {year, month, day} = calendar.date_from_iso_days(iso_days)
    %Date{year: year, month: month, day: day, calendar: calendar}
  end
end
