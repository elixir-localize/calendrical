defmodule Calendrical.Composite.Config do
  @moduledoc false

  @default_base_calendar Calendrical.Julian
  @default_base_date Macro.escape(Date.new!(-9999, 1, 1, Calendrical.Julian))

  @doc false
  # Return a list of dates representing calendar transitions
  # in order, prepending an origin date in the configured base
  # calendar (default `Calendrical.Julian`).
  def extract_options(options) when is_list(options) do
    {:%{}, [], [__struct__: Date, calendar: calendar, day: day, month: month, year: year]} =
      @default_base_date

    {:ok, default_base_date} = Date.new(year, month, day, calendar)
    base_calendar = Keyword.get(options, :base_calendar, @default_base_calendar)
    base_transition = %{default_base_date | calendar: base_calendar}

    options
    |> Keyword.get(:calendars)
    |> maybe_wrap()
    |> List.insert_at(0, base_transition)
    |> collect_dates!()
  end

  defp maybe_wrap(options) when is_list(options), do: options
  defp maybe_wrap(options), do: [options]

  @doc false
  def validate_options([]), do: {:error, :no_calendars_configured}

  def validate_options(options) when is_list(options) do
    case Keyword.fetch(options, :calendars) do
      {:ok, calendars} ->
        calendars = if is_list(calendars), do: calendars, else: [calendars]

        if all_dates?(calendars) do
          {:ok, Keyword.put(options, :calendars, calendars)}
        else
          {:error, :must_be_a_list_of_dates}
        end

      :error ->
        {:error, :no_calendars_configured}
    end
  end

  defp all_dates?(calendars) do
    Enum.all?(calendars, fn
      %{year: _, month: _, day: _, calendar: _} -> true
      _ -> false
    end)
  end

  # Convert a list of `%Date{}` transition markers into
  # `{iso_days, year, month, day, calendar}` tuples sorted by
  # `iso_days`.
  defp collect_dates!(calendars) when is_list(calendars) do
    calendars
    |> Enum.map(fn
      %{year: year, month: month, day: day, calendar: calendar} ->
        calendar = if calendar == Calendar.ISO, do: Calendrical.Gregorian, else: calendar
        {calendar.date_to_iso_days(year, month, day), year, month, day, calendar}

      other ->
        raise ArgumentError, "Unknown date found: #{inspect(other)}"
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc false
  # The segments of the time line, one per member calendar in order: the
  # ISO days each governs (the last is open-ended), the label years they
  # carry, and their first and last months in the calendar's civil
  # numbering. A Julian year-start variant counts its months as the
  # Julian calendar does, from January, whatever its labels say; any
  # other calendar counts its own. The first segment is open-ended before.
  def segments(config) do
    ends =
      config
      |> Enum.drop(1)
      |> Enum.map(fn {iso_days, _year, _month, _day, _calendar} -> iso_days - 1 end)

    config
    |> Enum.zip(ends ++ [nil])
    |> Enum.with_index()
    |> Enum.map(fn {{{first, _year, _month, _day, calendar}, last}, index} ->
      civil = civil_calendar(calendar)
      first? = index > 0

      %{
        first: first,
        last: last,
        calendar: calendar,
        civil: civil,
        first_year: if(first?, do: label_year(calendar, first)),
        last_year: if(last, do: label_year(calendar, last)),
        first_month: if(first?, do: civil_month(civil, first)),
        last_month: if(last, do: civil_month(civil, last)),
        january_year?: january_year?(calendar, civil)
      }
    end)
  end

  # Whether the calendar's years begin on 1 January, so its quarters are
  # the months in label order. A Julian year-start variant beginning on
  # another day labels January with the year before.
  defp january_year?(calendar, calendar), do: true

  defp january_year?(calendar, _civil) do
    calendar.date_from_julian_date(2000, 1, 1) == {2000, 1, 1}
  end

  defp civil_calendar(calendar) do
    if Code.ensure_loaded?(calendar) and function_exported?(calendar, :date_from_julian_date, 3),
      do: Calendrical.Julian,
      else: calendar
  end

  defp label_year(calendar, iso_days) do
    {year, _month, _day} = calendar.date_from_iso_days(iso_days)
    year
  end

  defp civil_month(civil, iso_days) do
    {year, month, _day} = civil.date_from_iso_days(iso_days)
    {year, month}
  end

  @doc false
  # The `{year, month}` labels of the months a transition cuts short or
  # splits: the month holding the last day of the old calendar and the
  # month holding the first day of the new one. Only these months need
  # their days counted one by one.
  def transition_months(config) do
    config
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [{_, _, _, _, old_calendar}, {iso_days, year, month, _day, _new}] ->
      {old_year, old_month, _old_day} = old_calendar.date_from_iso_days(iso_days - 1)
      [{old_year, old_month}, {year, month}]
    end)
    |> Enum.uniq()
  end
end
