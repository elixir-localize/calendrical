defmodule Calendrical.Compiler.DateCheck do
  @moduledoc false

  # The two era primitives a calendar may override, `year_of_era/3` and
  # `day_of_era/3`, answer a question about a date only for a date the
  # calendar has: a date its `valid_date?/3` rejects is
  # `{:error, :invalid_date}`, never a raise nor an answer for some other
  # date, and a date missing a field is a `Calendrical.MissingFieldsError`.
  # Each maker registers this hook after its definitions, so it wraps the
  # definition a calendar ends with, the derived one or the calendar's own,
  # and the check is made once however the primitive is implemented. Every
  # other derived function checks its date itself.

  @date_callbacks [day_of_era: 3, year_of_era: 3]

  @whole_date [:year, :month, :day]

  # The month and week bases answer a date missing fields a question does
  # not need: a year's era and number from the year alone, a quarter from
  # the year and month, and a month from itself. Every other question, and
  # every question to a calendar of another base, needs the whole date.
  @partial_dates %{
    year_of_era: [:year],
    calendar_year: [:year],
    extended_year: [:year],
    related_gregorian_year: [:year],
    cyclic_year: [:year],
    quarter_of_year: [:year, :month],
    month_of_year: [:month]
  }

  defmacro __before_compile__(env), do: wrap(env.module, %{})

  defp wrap(module, needed_fields) do
    callbacks =
      for {name, arity} <- @date_callbacks,
          Module.defines?(module, {name, arity}, :def),
          do: {name, arity}

    wrappers =
      for {name, arity} <- callbacks do
        arguments = Macro.generate_arguments(arity, __MODULE__)
        [year, month, day | _rest] = arguments
        needed = Map.get(needed_fields, name, @whole_date)
        dayless? = Map.has_key?(@partial_dates, name)
        function = Atom.to_string(name)

        quote do
          def unquote(name)(unquote_splicing(arguments)) do
            case Calendrical.Compiler.DateCheck.check(
                   __MODULE__,
                   unquote(needed),
                   {unquote(year), unquote(month), unquote(day)},
                   unquote(dayless?)
                 ) do
              :ok ->
                super(unquote_splicing(arguments))

              :missing ->
                {:error,
                 Calendrical.missing_date_error(
                   unquote(function),
                   unquote(year),
                   unquote(month),
                   unquote(day)
                 )}

              :invalid ->
                {:error, :invalid_date}
            end
          end
        end
      end

    quote do
      defoverridable unquote(callbacks)
      unquote_splicing(wrappers)
    end
  end

  @doc false
  # Whether a question may be put to the calendar: `:ok` for a date it has,
  # or one missing only fields the question does not need; `:missing` for
  # one missing a field the question needs; `:invalid` for one it does not
  # have. A year and a month without the day are checked as the month's
  # first day; a field that is neither an integer nor missing, and a month
  # or a day below 1, are no calendar's.
  #
  # A question that needs no day (`dayless?`: a year's numbers, a month's
  # quarter and its month of the year) takes the 1st of a month the year
  # holds as the month's first day, as a date without a day is asked about,
  # where the month begins after its 1st: a reform began England's 1751 on
  # 25 March, so that March holds the 25th to the 31st and its 1st names
  # the month. Every other day the calendar does not have is an error.
  @spec check(module(), [:year | :month | :day], {term(), term(), term()}, boolean()) ::
          :ok | :missing | :invalid
  def check(calendar, _needed, {year, month, day}, dayless?)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    cond do
      calendar.valid_date?(year, month, day) -> :ok
      dayless? and day == 1 -> first_day(calendar, year, month)
      true -> :invalid
    end
  end

  def check(calendar, needed, {year, month, day}, _dayless?) do
    cond do
      not (field?(year) and field?(month) and field?(day)) -> :invalid
      not (ordinal?(month) and ordinal?(day)) -> :invalid
      missing?(needed, year, month, day) -> :missing
      is_integer(year) and is_integer(month) -> first_day(calendar, year, month)
      true -> :ok
    end
  end

  # The month's first day is the 1st, or where a change of calendar began
  # the month after it, the first day the month holds: the month is one the
  # year has, and the calendar counts days in it.
  defp first_day(calendar, year, month) do
    cond do
      calendar.valid_date?(year, month, 1) -> :ok
      month_holds_days?(calendar, year, month) -> :ok
      true -> :invalid
    end
  end

  defp month_holds_days?(calendar, year, month) do
    month >= 1 and month <= months_in_year(calendar, year) and
      days_held(calendar.days_in_month(year, month)) > 0
  end

  defp months_in_year(calendar, year) do
    case calendar.months_in_year(year) do
      months when is_integer(months) -> months
      _no_count -> 0
    end
  end

  defp days_held(days) when is_integer(days), do: days
  defp days_held(_no_count), do: 0

  defp missing?(needed, year, month, day) do
    (:year in needed and is_nil(year)) or (:month in needed and is_nil(month)) or
      (:day in needed and is_nil(day))
  end

  defp field?(value), do: is_integer(value) or is_nil(value)

  defp ordinal?(value), do: is_nil(value) or value >= 1
end
