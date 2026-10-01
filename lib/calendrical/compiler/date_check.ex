defmodule Calendrical.Compiler.DateCheck do
  @moduledoc false

  # A calendar answers a question about a date only for a date it has: a
  # date its `valid_date?/3` rejects is `{:error, :invalid_date}`, never a
  # raise nor an answer for some other date, and a date missing a field the
  # question needs is a `Calendrical.MissingFieldsError`. Each calendar base
  # registers this hook after its own, so it wraps the definition a calendar
  # ends with, the base's or the calendar's own override, and the check is
  # made once, however the callback is implemented.

  @date_callbacks [
    day_of_week: 4,
    day_of_year: 3,
    day_of_era: 3,
    year_of_era: 3,
    quarter_of_year: 3,
    month_of_year: 3,
    week_of_year: 3,
    iso_week_of_year: 3,
    week_of_month: 3,
    calendar_year: 3,
    extended_year: 3,
    related_gregorian_year: 3,
    cyclic_year: 3
  ]

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

  defmacro partial_dates(env), do: wrap(env.module, @partial_dates)

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
        function = Atom.to_string(name)

        quote do
          def unquote(name)(unquote_splicing(arguments)) do
            case Calendrical.Compiler.DateCheck.check(
                   __MODULE__,
                   unquote(needed),
                   {unquote(year), unquote(month), unquote(day)}
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
  @spec check(module(), [:year | :month | :day], {term(), term(), term()}) ::
          :ok | :missing | :invalid
  def check(calendar, _needed, {year, month, day})
      when is_integer(year) and is_integer(month) and is_integer(day) do
    if calendar.valid_date?(year, month, day), do: :ok, else: :invalid
  end

  def check(calendar, needed, {year, month, day}) do
    cond do
      not (field?(year) and field?(month) and field?(day)) -> :invalid
      not (ordinal?(month) and ordinal?(day)) -> :invalid
      missing?(needed, year, month, day) -> :missing
      is_integer(year) and is_integer(month) -> first_day(calendar, year, month)
      true -> :ok
    end
  end

  defp first_day(calendar, year, month) do
    if calendar.valid_date?(year, month, 1), do: :ok, else: :invalid
  end

  defp missing?(needed, year, month, day) do
    (:year in needed and is_nil(year)) or (:month in needed and is_nil(month)) or
      (:day in needed and is_nil(day))
  end

  defp field?(value), do: is_integer(value) or is_nil(value)

  defp ordinal?(value), do: is_nil(value) or value >= 1
end
