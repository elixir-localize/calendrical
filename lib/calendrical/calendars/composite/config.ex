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
    with {:ok, calendars} <- Keyword.fetch(options, :calendars) do
      calendars = if is_list(calendars), do: calendars, else: [calendars]

      if all_dates?(calendars) do
        {:ok, Keyword.put(options, :calendars, calendars)}
      else
        {:error, :must_be_a_list_of_dates}
      end
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
  # A small `reduce` variant that passes both the head element *and*
  # the rest of the list to the reducer. Used by the composite
  # compiler so it can generate `def days_in_month/2` clauses that
  # know about the *next* transition as well as the current one.
  def define_transition_functions(list, fun) do
    do_reduce_peeking(list, [], fn head, tail, acc ->
      acc ++ List.wrap(fun.(head, tail))
    end)
  end

  defp do_reduce_peeking([], acc, _fun), do: acc

  defp do_reduce_peeking([head | tail], acc, fun) do
    do_reduce_peeking(tail, fun.(head, tail, acc), fun)
  end
end
