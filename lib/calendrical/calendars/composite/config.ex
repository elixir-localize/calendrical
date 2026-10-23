defmodule Calendrical.Composite.Config do
  @moduledoc false

  @default_base_calendar Calendrical.Julian
  @known_options [:calendars, :base_calendar]

  # The base calendar has no first day. This is the date it is listed by,
  # never converted: an astronomical base calendar has no day so far back.
  @base_date {-9999, 1, 1}

  @doc false
  # The calendars of a composite calendar as `{iso_days, year, month, day,
  # calendar}`: the base calendar, which has no first day, so its ISO day is
  # `nil` and it is listed by its 1 January -9999, and then each calendar
  # that takes effect, in the order of the days they take effect on. The options are those of
  # `use Calendrical.Composite`, so options that do not make a calendar
  # raise, at compile time.
  def extract_options(options) when is_list(options) do
    case validate_options(options) do
      {:ok, options} -> config(options)
      {:error, exception} -> raise exception
    end
  end

  defp config(options) do
    {year, month, day} = @base_date
    base_calendar = Keyword.get(options, :base_calendar, @default_base_calendar)
    base = {nil, year, month, day, member(base_calendar)}

    changes =
      options
      |> Keyword.fetch!(:calendars)
      |> Enum.map(&change/1)
      |> Enum.sort_by(&elem(&1, 0))

    [base | changes]
  end

  defp change(%{year: year, month: month, day: day, calendar: calendar}) do
    calendar = member(calendar)
    {calendar.date_to_iso_days(year, month, day), year, month, day, calendar}
  end

  @doc false
  # The options of a composite calendar with `:calendars` as a list, or the
  # reason they make no calendar a composite can keep.
  #
  # Each of `:calendars` is a date of the calendar that takes effect on it,
  # on a day of its own, and every calendar is a calendar module of months
  # that is no composite itself: a composite counts months across a change
  # of calendar, which the weeks of a calendar of weeks are not, and the
  # months of one composite are not counted through from another. A calendar
  # does not take the number of the year back from the calendar before it.
  # Its years would carry numbers the years of the calendar before have too,
  # and a date of those years names only one day: the Hebrew calendar
  # followed by the Gregorian from 1900 would leave the Hebrew years from
  # 1900 to 5660 no dates. A year's number may stay the same through a
  # change, as it does where the day a year begins on changes.
  #
  # The calendars are asked about the dates given, and one that raises for
  # a date it does not reach is the reason.
  def validate_options([]), do: refuse(:no_calendars_configured)

  def validate_options(options) when is_list(options) do
    with :ok <- known_options(options),
         {:ok, calendars} <- calendars(options),
         :ok <- validate_calendar(Keyword.get(options, :base_calendar, @default_base_calendar)),
         :ok <- validate_dates(calendars),
         options = Keyword.put(options, :calendars, calendars),
         :ok <- validate_changes(config(options)) do
      {:ok, options}
    end
  rescue
    exception -> {:error, exception}
  end

  # An option no composite reads is refused, as the other makers refuse one.
  defp known_options(options) do
    case Keyword.keys(options) -- @known_options do
      [] ->
        :ok

      unknown ->
        {:error,
         Calendrical.UnknownOptionError.exception(
           maker: Calendrical.Composite,
           options: unknown,
           known_options: @known_options
         )}
    end
  end

  defp calendars(options) do
    case Keyword.fetch(options, :calendars) do
      {:ok, calendars} when is_list(calendars) ->
        if List.improper?(calendars),
          do: refuse(:must_be_a_list_of_dates, calendars),
          else: {:ok, calendars}

      {:ok, calendar} ->
        {:ok, [calendar]}

      :error ->
        refuse(:no_calendars_configured)
    end
  end

  defp validate_dates(calendars) do
    Enum.find_value(calendars, :ok, fn
      %{year: year, month: month, day: day, calendar: calendar} = date ->
        with :ok <- validate_calendar(calendar),
             :ok <- validate_date(date, calendar, year, month, day),
             do: nil

      not_a_date ->
        refuse(:must_be_a_list_of_dates, not_a_date)
    end)
  end

  # Fields that are not integers are no date, whatever the calendar says.
  defp validate_date(date, calendar, year, month, day)
       when is_integer(year) and is_integer(month) and is_integer(day) do
    if member(calendar).valid_date?(year, month, day),
      do: :ok,
      else: refuse(:invalid_date, date)
  end

  defp validate_date(date, _calendar, _year, _month, _day), do: refuse(:invalid_date, date)

  # A calendar module is one `Calendrical.validate_calendar/1` takes for
  # one. It is waited for here where it is being compiled along with the
  # composite calendar, which that function does not do.
  defp validate_calendar(calendar) do
    calendar = member(calendar)

    cond do
      not calendar_module?(calendar) ->
        {:error, Calendrical.InvalidCalendarModuleError.exception(module: calendar)}

      Calendrical.Base.Common.composite?(calendar) ->
        refuse(:must_not_be_composite_calendars, calendar)

      function_exported?(calendar, :calendar_base, 0) and calendar.calendar_base() == :week ->
        refuse(:must_not_be_week_calendars, calendar)

      true ->
        :ok
    end
  end

  defp calendar_module?(calendar) do
    is_atom(calendar) and match?({:module, _module}, Code.ensure_compiled(calendar)) and
      Calendrical.Base.Common.calendar_behaviours?(calendar)
  end

  defp member(Calendar.ISO), do: Calendrical.Gregorian
  defp member(calendar), do: calendar

  # Each change of calendar after the one before it: on a later day, and
  # in a year that is not numbered before the year of the day before it.
  defp validate_changes(config) do
    config
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.find_value(:ok, fn {[
                                  {before, _, _, _, calendar},
                                  {iso_days, year, month, day, incoming}
                                ], index} ->
      {last_year, _month, _day} = calendar.date_from_iso_days(iso_days - 1)
      change = %Date{year: year, month: month, day: day, calendar: incoming}

      cond do
        index > 0 and iso_days == before -> refuse(:must_take_effect_on_different_days, change)
        year < last_year -> refuse(:years_must_not_go_back, change)
        true -> nil
      end
    end)
  end

  defp refuse(reason, value \\ nil),
    do: {:error, Calendrical.InvalidCompositeError.exception(reason: reason, value: value)}

  @doc false
  # The segments of the time line, one per member calendar in order: the
  # ISO days each governs (the last is open-ended), the label years they
  # carry, and their first and last months in the member's own numbering
  # — a Julian year-start variant's counted months among them. The first
  # segment is open-ended before: the base calendar has no first day.
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
        first: if(first?, do: first),
        last: last,
        calendar: calendar,
        civil: civil,
        first_year: if(first?, do: label_year(calendar, first)),
        last_year: if(last, do: label_year(calendar, last)),
        first_month: if(first?, do: civil_month(civil, first)),
        last_month: if(last, do: civil_month(civil, last))
      }
    end)
  end

  # The calendar whose months a segment's months and years are walked in.
  # A year begun elsewhere in a base calendar's year counts its months from
  # that day, so a year reckoned from 25 March has thirteen, its March
  # split in two, where it names twelve: its months are walked as the base
  # calendar's months that name them, from January, and its days as their
  # days in the base calendar, which `base/0` names. Any
  # other calendar walks its own.
  defp civil_calendar(calendar) do
    if Code.ensure_loaded?(calendar) and function_exported?(calendar, :base, 0),
      do: calendar.base(),
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
