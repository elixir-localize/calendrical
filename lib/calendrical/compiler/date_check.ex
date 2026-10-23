defmodule Calendrical.Compiler.DateCheck do
  @moduledoc false

  # The two era primitives a calendar may override, `year_of_era/3` and
  # `day_of_era/3`, and `shift/6`, answer a question about a date only for a date the
  # calendar has: a date its `valid_date?/3` rejects is a
  # `Calendrical.InvalidDateError`, never a raise nor an answer for some other
  # date, and a date missing a field is a `Calendrical.MissingFieldsError`.
  # Each maker registers this hook after its definitions, so it wraps the
  # definition a calendar ends with, the derived one or the calendar's own,
  # and the check is made once however the primitive is implemented. Every
  # other derived function checks its date itself.
  #
  # `days_in_month/2` is wrapped too, so every calendar answers a month the
  # same way: the count for a month its year has, and otherwise an error
  # tuple, never a count for some other month, a 0 or a raise. A month the
  # year does not have is a `Calendrical.InvalidMonthError`, a missing field
  # a `Calendrical.MissingFieldsError`, and a year outside a calendar's
  # `@supported_years` a `Calendrical.UnsupportedDateRangeError`. A
  # composite calendar answers this itself, since it counts its months by
  # their days.

  # `shift/6` is checked too: a shift of what is no date is an error, never
  # a shift of its fields to some other non-date.
  @date_callbacks [day_of_era: 3, year_of_era: 3, shift: 6]

  # Both need the whole date: an era can begin on any day of a month, as
  # Reiwa began on 1 May 2019. `year_of_era/1` answers from a year alone.
  @whole_date [:year, :month, :day]

  # A question about a year's era takes the 1st of a month the year holds
  # as the month's first day, where a reform began the month after its 1st.
  @dayless_questions [:year_of_era]

  # The parts `shift/6` adds and `diff/3` counts; any other is a
  # `Calendrical.InvalidPartError`, as `Calendrical.diff/3` answers one.
  @valid_parts [:years, :quarters, :months, :weeks, :days]

  defmacro __before_compile__(env), do: wrap(env.module)

  defp wrap(module) do
    callbacks =
      for {name, arity} <- @date_callbacks,
          Module.defines?(module, {name, arity}, :def),
          do: {name, arity}

    wrappers =
      for {name, arity} <- callbacks do
        arguments = Macro.generate_arguments(arity, __MODULE__)
        [year, month, day | _rest] = arguments
        needed = @whole_date
        dayless? = name in @dayless_questions
        function = Atom.to_string(name)
        call = super_call(name, arguments)

        quote do
          def unquote(name)(unquote_splicing(arguments)) do
            case Calendrical.Compiler.DateCheck.check(
                   __MODULE__,
                   unquote(needed),
                   {unquote(year), unquote(month), unquote(day)},
                   unquote(dayless?)
                 ) do
              :ok ->
                unquote(call)

              :missing ->
                {:error,
                 Calendrical.missing_date_error(
                   unquote(function),
                   unquote(year),
                   unquote(month),
                   unquote(day)
                 )}

              :invalid ->
                {:error,
                 Calendrical.InvalidDateError.exception(
                   calendar: __MODULE__,
                   value: {unquote(year), unquote(month), unquote(day)}
                 )}
            end
          end
        end
      end

    quote do
      defoverridable unquote(callbacks)
      unquote_splicing(wrappers)
      unquote(diff_wrapper(module))
      unquote(month_wrapper(module))
      unquote(year_wrapper(module))
    end
  end

  # `shift/6` adds one of the five parts, so the part is checked once the
  # date is.
  defp super_call(:shift, arguments) do
    part = Enum.at(arguments, 3)

    quote do
      case Calendrical.Compiler.DateCheck.check_part(unquote(part)) do
        :ok -> super(unquote_splicing(arguments))
        {:error, _exception} = error -> error
      end
    end
  end

  defp super_call(_name, arguments), do: quote(do: super(unquote_splicing(arguments)))

  # `diff/3` counts between two dates the calendar has, in one of the five
  # parts: what is no date, or no part, is an error, never a count.
  defp diff_wrapper(module) do
    if Module.defines?(module, {:diff, 3}, :def) do
      quote do
        defoverridable diff: 3

        def diff(from, to, date_part) do
          with :ok <- Calendrical.Compiler.DateCheck.check_date(__MODULE__, "diff", from),
               :ok <- Calendrical.Compiler.DateCheck.check_date(__MODULE__, "diff", to),
               :ok <- Calendrical.Compiler.DateCheck.check_part(date_part) do
            super(from, to, date_part)
          end
        end
      end
    end
  end

  @doc false
  # A `{year, month, day}` the calendar has is `:ok`; one missing a field is
  # a `Calendrical.MissingFieldsError`, and anything else a
  # `Calendrical.InvalidDateError`.
  @spec check_date(module(), String.t(), term()) :: :ok | {:error, Exception.t()}
  def check_date(calendar, function, {year, month, day} = date) do
    case check(calendar, @whole_date, date, false) do
      :ok ->
        :ok

      :missing ->
        {:error, Calendrical.missing_date_error(function, year, month, day)}

      :invalid ->
        {:error, Calendrical.InvalidDateError.exception(calendar: calendar, value: date)}
    end
  end

  def check_date(calendar, _function, other),
    do: {:error, Calendrical.InvalidDateError.exception(calendar: calendar, value: other)}

  @doc false
  @spec check_part(term()) :: :ok | {:error, Exception.t()}
  def check_part(part) when part in @valid_parts, do: :ok

  def check_part(part),
    do: {:error, Calendrical.InvalidPartError.exception(part: part, valid_parts: @valid_parts)}

  # A year that is missing, or no integer, is answered before
  # `months_in_year/1` is asked: `nil` as a missing field, as
  # `days_in_year/1` answers it, and anything else as no year.
  defp year_wrapper(module) do
    if Module.defines?(module, {:months_in_year, 1}, :def) do
      quote do
        defoverridable months_in_year: 1

        def months_in_year(year) when is_integer(year), do: super(year)

        def months_in_year(nil) do
          {:error,
           Calendrical.MissingFieldsError.exception(
             function: "months_in_year",
             fields: [year: nil]
           )}
        end

        def months_in_year(year) do
          {:error,
           Calendrical.InvalidDateError.exception(calendar: __MODULE__, value: [year: year])}
        end
      end
    end
  end

  # A composite calendar counts its months by the days in them, so it
  # answers a month it does not have itself (`Calendrical.Composite`).
  defp month_wrapper(module) do
    if Module.defines?(module, {:days_in_month, 2}, :def) and
         not Module.has_attribute?(module, :member_calendars) do
      supported_years = Module.get_attribute(module, :supported_years)

      quote do
        defoverridable days_in_month: 2

        unquote(unsupported_year(supported_years))

        def days_in_month(year, month) when is_integer(year) and is_integer(month) do
          if month >= 1 and month <= months_in_year(year) do
            super(year, month)
          else
            {:error,
             Calendrical.InvalidMonthError.exception(
               calendar: __MODULE__,
               year: year,
               month: month
             )}
          end
        end

        def days_in_month(year, month) when is_nil(year) or is_nil(month) do
          {:error,
           Calendrical.MissingFieldsError.exception(
             function: "days_in_month",
             fields: [year: year, month: month]
           )}
        end

        def days_in_month(year, month) do
          {:error,
           Calendrical.InvalidMonthError.exception(calendar: __MODULE__, year: year, month: month)}
        end
      end
    end
  end

  # A calendar that reckons only some years, as its `@supported_years`
  # states, answers a year outside them before asking how many months it has.
  defp unsupported_year(nil), do: nil

  defp unsupported_year(supported_years) do
    quote do
      def days_in_month(year, month)
          when is_integer(year) and is_integer(month) and
                 year not in unquote(Macro.escape(supported_years)) do
        {:error,
         Calendrical.UnsupportedDateRangeError.exception(
           calendar: __MODULE__,
           value: year,
           range: unquote(Macro.escape(supported_years))
         )}
      end
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
  # A question about a year's era (`dayless?`) takes the 1st of a month the year
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

  # Asked through `valid_date?/3` alone, which answers false rather than
  # raising for a year a calendar cannot reckon (an observational calendar
  # outside the ephemeris), where `days_in_month/2` would raise.
  defp month_holds_days?(calendar, year, month) do
    case calendar.days_in_month_bounds(month) do
      {fewest, most} when is_integer(fewest) and is_integer(most) ->
        Enum.any?(2..most//1, &calendar.valid_date?(year, month, &1))

      _no_such_month ->
        false
    end
  end

  defp missing?(needed, year, month, day) do
    (:year in needed and is_nil(year)) or (:month in needed and is_nil(month)) or
      (:day in needed and is_nil(day))
  end

  defp field?(value), do: is_integer(value) or is_nil(value)

  defp ordinal?(value), do: is_nil(value) or value >= 1
end
