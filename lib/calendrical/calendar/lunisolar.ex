defmodule Calendrical.Calendar.Lunisolar do
  @moduledoc """
  Makes a lunisolar calendar reckoned from the sky: a year of twelve or
  thirteen lunar months that begins at the second new moon after the
  winter solstice, with the leap month placed by the solar terms, as the
  Chinese, Korean, Vietnamese and traditional Japanese calendars are.

  The maker supplies the whole kernel from `Calendrical.Lunisolar`, which
  is parametrised by the calendar's epoch and the place it is reckoned
  at, and the functions a lunisolar calendar is asked beyond the kernel:
  a date from a traditional month, the Gregorian date of a lunar date,
  and the new year of a Gregorian year. A module keeps its own extras, as
  the festivals, beside them.

  ### Options

  * `:epoch` is the first day of the calendar's year 1, as a `t:Date.t/0`.

  * `:location` is the place the calendar is reckoned at, a function of
    the ISO day number giving `{latitude, longitude, altitude, offset}`
    as `Astro` takes them.

  * `:cldr_calendar_type` is the CLDR calendar whose data names the
    months, `:chinese` by default.

  * `:era_calendar_type` is the CLDR calendar whose eras the calendar
    counts years in, the CLDR calendar type by default.

  ### Supported years

  A calendar answers for the 40,001 years numbered, from the Gregorian
  year of its epoch, as Gregorian years -20,000 to 20,000:
  `Calendrical.Chinese` years -17,363 to 22,637, which run from late
  -20,001 to early 20,001. Beyond them the new moons the calendar is
  reckoned from drift from their mean timing faster than a search can
  follow, so:

  * `valid_date?/3` is `false`, and a question about a date (`year/1`,
    `days_in_year/1`, `day_of_week/4`, `year_of_era/3` and the rest)
    answers `{:error, %Calendrical.InvalidDateError{}}`, as for any date the
    calendar lacks.

  * `new/3` and `days_in_month/2` return
    `{:error, %Calendrical.UnsupportedDateRangeError{}}`.

  * `date_to_iso_days/3`, `date_from_iso_days/1`, `leap_year?/1`,
    `leap_month/1`, `leap_month?/2`, `months_in_year/1` and, for a
    Gregorian year outside -20,000 to
    20,000, `gregorian_date_for_lunar/3` raise
    `Calendrical.UnsupportedDateRangeError`, as the sighting Islamic
    calendars do outside their ephemeris.

  ### Examples

      defmodule Chinese do
        use Calendrical.Calendar.Lunisolar,
          epoch: ~D[-2636-02-15],
          location: &__MODULE__.location/1

        def location(_iso_days), do: {39.9, 116.4, 44, 8 / 24}
      end

  """

  @known_options [:epoch, :location, :cldr_calendar_type, :era_calendar_type]

  # The Gregorian years whose lunar years a calendar answers for: across
  # them the series for the moment of a new moon stays within half a month
  # of the mean lunation, so finding one takes a few evaluations. Far
  # beyond, its higher-order terms move it by thousands of months.
  @supported_gregorian_years -20_000..20_000

  defmacro __using__(options) do
    refuse_unknown_options!(options, @known_options)
    cldr_calendar_type = Keyword.get(options, :cldr_calendar_type, :chinese)
    location = Keyword.fetch!(options, :location)

    behaviour_options = [
      epoch: Keyword.fetch!(options, :epoch),
      cldr_calendar_type: cldr_calendar_type,
      era_calendar_type: Keyword.get(options, :era_calendar_type, cldr_calendar_type),
      months_in_year: {12, 13},
      year_cycle: 60,
      location: location
    ]

    [
      quote do
        use Calendrical.Calendar, unquote(behaviour_options)

        alias Calendrical.Lunisolar

        @location unquote(location)
        @supported_gregorian_years unquote(Macro.escape(@supported_gregorian_years))
        @supported_years Calendrical.Calendar.Lunisolar.supported_years(
                           unquote(Keyword.fetch!(options, :epoch)),
                           @supported_gregorian_years
                         )
      end,
      traditional_dates(),
      gregorian_dates(),
      kernel(),
      checks(),
      supported_range(),
      written()
    ]
  end

  # A date from a traditional month.
  defp traditional_dates do
    quote location: :keep do
      @doc """
      Returns a date of this calendar from a year, a traditional lunar
      month and a day.

      ### Arguments

      * `year` is a year of this calendar.

      * `lunar_month` is a traditional month, 1 to 12, or `{month, :leap}`
        for the leap month that follows it.

      * `day` is a day of the month.

      ### Returns

      * `{:ok, date}` with the date in this calendar, or

      * `{:error, %Calendrical.InvalidDateError{}}` for what is no date, or

      * `{:error, %Calendrical.UnsupportedDateRangeError{}}` for a year
        outside the supported years.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {:ok, %Date{month: 1, day: 1}} = #{inspect(__MODULE__)}.new(today.year, 1, 1)
          iex> {:error, %Calendrical.InvalidDateError{}} = #{inspect(__MODULE__)}.new(today.year, 1, 31)

      """
      def new(year, _lunar_month, _day) when is_integer(year) and year not in @supported_years,
        do: {:error, out_of_range(year)}

      def new(year, lunar_month, day) do
        # The engine is not told the calendar, so its error names this one.
        case Lunisolar.ordinal_date(year, lunar_month, day, epoch(), @location) do
          {:ok, {year, month, day}} ->
            {:ok, %Date{year: year, month: month, day: day, calendar: __MODULE__}}

          {:error, exception} ->
            {:error, %{exception | calendar: __MODULE__}}
        end
      end

      @doc """
      Returns a date of this calendar from a year, a traditional lunar
      month and a day, raising for what is no date (see `new/3`).

      ### Arguments

      * `year` is a year of this calendar.

      * `lunar_month` is a traditional month, 1 to 12, or `{month, :leap}`
        for the leap month that follows it.

      * `day` is a day of the month.

      ### Returns

      * The `t:Date.t/0` in this calendar.

      Raises `Calendrical.InvalidDateError` for what is no date, and
      `Calendrical.UnsupportedDateRangeError` for a year outside the
      supported years.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> %Date{month: 1, day: 1} = #{inspect(__MODULE__)}.new!(today.year, 1, 1)
      """
      def new!(year, lunar_month, day) do
        case new(year, lunar_month, day) do
          {:ok, date} -> date
          {:error, exception} -> raise exception
        end
      end
    end
  end

  # Whether a month is the leap month, the Gregorian date of a lunar date
  # and the new year of a Gregorian year.
  defp gregorian_dates do
    quote location: :keep do
      @doc """
      Returns whether a month of a year is the leap month.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is an ordinal month of the year, counting the leap month.

      ### Returns

      * `true` if the month is the year's leap month, otherwise `false`,
        as it is for anything but an integer year.

      Raises `Calendrical.UnsupportedDateRangeError` for a year outside the
      supported years (see the module documentation).

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.leap_month?(today.year, 0)
          false

      """
      def leap_month?(year, month) when is_integer(year) do
        Lunisolar.leap_month?(supported_year!(year), month, epoch(), @location)
      end

      def leap_month?(_not_a_year, _month), do: false

      @doc """
      Returns the Gregorian date of a traditional lunar month and day in
      the lunar year that begins in a Gregorian year.

      ### Arguments

      * `gregorian_year` is a Gregorian year.

      * `lunar_month` is a traditional month, 1 to 12, or `{month, :leap}`.

      * `lunar_day` is a day of the month.

      ### Returns

      * A `t:Date.t/0` in `Calendar.ISO`.

      Raises `ArgumentError` when the lunar year has no such month, or
      the month no such day, and `Calendrical.UnsupportedDateRangeError`
      for a Gregorian year outside -20,000 to 20,000.

      ### Examples

          iex> %Date{calendar: Calendar.ISO, year: 2024} = #{inspect(__MODULE__)}.gregorian_date_for_lunar(2024, 1, 1)

          iex> #{inspect(__MODULE__)}.gregorian_date_for_lunar(2024, 1, 40)
          ** (ArgumentError) the lunar year beginning in 2024 has no month 1 day 40

      """
      def gregorian_date_for_lunar(gregorian_year, _lunar_month, _lunar_day)
          when is_integer(gregorian_year) and gregorian_year not in @supported_gregorian_years,
          do: raise(out_of_range(gregorian_year))

      def gregorian_date_for_lunar(gregorian_year, lunar_month, lunar_day) do
        {year, month, day} =
          Lunisolar.gregorian_date_for_lunar(
            gregorian_year,
            lunar_month,
            lunar_day,
            epoch(),
            @location
          )

        Date.new!(year, month, day)
      end

      @doc """
      Returns the Gregorian date of the new year that begins the lunar
      year of a Gregorian year.

      ### Arguments

      * `gregorian_year` is a Gregorian year.

      ### Returns

      * A `t:Date.t/0` in `Calendar.ISO`.

      ### Examples

          iex> #{inspect(__MODULE__)}.new_year_for_gregorian_year(2024) == #{inspect(__MODULE__)}.gregorian_date_for_lunar(2024, 1, 1)
          true
      """
      def new_year_for_gregorian_year(gregorian_year) do
        gregorian_date_for_lunar(gregorian_year, 1, 1)
      end
    end
  end

  # The kernel from `Calendrical.Lunisolar`.
  defp kernel do
    quote location: :keep do
      @doc """
      Returns whether a year has thirteen months.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * `true` if the year has thirteen months, otherwise `false`.

      Raises `Calendrical.UnsupportedDateRangeError` for a year outside the
      supported years (see the module documentation).

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.leap_year?(today.year) == (#{inspect(__MODULE__)}.months_in_year(today.year) == 13)
          true
      """
      @impl Calendar
      def leap_year?(year) when is_integer(year) do
        Lunisolar.leap_year?(supported_year!(year), epoch(), @location)
      end

      @doc """
      Returns the position of the year's leap month, or `nil`.

      ### Arguments

      * `year` is a year of this calendar.

      ### Returns

      * The ordinal month that is the leap month, counting it among the
        year's months, or `nil` if the year has none, as for anything but
        an integer year.

      Raises `Calendrical.UnsupportedDateRangeError` for a year outside the
      supported years (see the module documentation).

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.leap_month(today.year) in [nil | Enum.to_list(2..13)]
          true

      """
      @impl true
      def leap_month(year) when is_integer(year) do
        Lunisolar.leap_month(supported_year!(year), epoch(), @location)
      end

      def leap_month(_not_a_year), do: nil

      @doc false
      @impl true
      def date_to_iso_days(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) do
        Lunisolar.date_to_iso_days(supported_year!(year), month, day, epoch(), @location)
      end

      @doc false
      @impl true
      def date_from_iso_days(iso_days) do
        {gregorian_year, _month, _day} = Calendar.ISO.date_from_iso_days(iso_days)

        # A day within a year of the Gregorian bound is read, and its lunar
        # year checked; one further away is refused before any new moon is
        # sought.
        if gregorian_year in (@supported_gregorian_years.first - 1)..(@supported_gregorian_years.last +
                                                                        1)//1 do
          {year, month, day} = Lunisolar.date_from_iso_days(iso_days, epoch(), @location)
          {supported_year!(year), month, day}
        else
          raise out_of_range(Date.from_gregorian_days(iso_days))
        end
      end
    end
  end

  # Whether a date is a date of this calendar, the days of a month, the
  # supported years and the difference between two dates.
  defp checks do
    quote location: :keep do
      @doc """
      Returns whether a year, month and day are a date of this calendar.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is an ordinal month of the year.

      * `day` is a day of the month.

      ### Returns

      * `true` if they are a date of this calendar, otherwise `false`, as
        for a year outside the supported years.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.valid_date?(today.year, today.month, today.day)
          true
          iex> #{inspect(__MODULE__)}.valid_date?(today.year, today.month, 31)
          false
      """
      @impl true
      def valid_date?(year, _month, _day) when is_integer(year) and year not in @supported_years,
        do: false

      def valid_date?(year, month, day) do
        Lunisolar.valid_date?(year, month, day, epoch(), @location)
      end

      @doc """
      Returns the number of days in a month of a year, 29 or 30.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is an ordinal month of the year.

      ### Returns

      * `29` or `30`, or

      * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year
        does not have, or

      * `{:error, %Calendrical.UnsupportedDateRangeError{}}` for a year
        outside the supported years (see the module documentation), or

      * `{:error, %Calendrical.MissingFieldsError{}}` where the year or the
        month is `nil`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.days_in_month(today.year, today.month) in [29, 30]
          true
      """
      @impl true
      # A year outside the supported years, a month the year does not have
      # and a field that is not an integer are answered before this by
      # `Calendrical.Compiler.DateCheck`.
      def days_in_month(year, month) do
        Lunisolar.days_in_month(year, month, epoch(), @location)
      end

      @doc """
      Returns the number of whole years, quarters, months, weeks or days
      from one date to another, the months counted through the leap
      months of the years between.

      ### Arguments

      * `from` is a `{year, month, day}` of this calendar.

      * `to` is a `{year, month, day}` of this calendar.

      * `date_part` is one of `:years`, `:quarters`, `:months`, `:weeks`
        or `:days`.

      ### Returns

      * The number of whole units, negative when `to` is before `from`.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> #{inspect(__MODULE__)}.diff({today.year, 1, 1}, {today.year + 1, 1, 1}, :years)
          1
      """
      @impl true
      def diff(from, to, date_part) do
        Calendrical.Base.Common.diff(__MODULE__, from, to, date_part, &months_between/3)
      end

      defp months_between(_calendar, from, to),
        do: Lunisolar.months_between(from, to, epoch(), @location)
    end
  end

  # The supported years and the error for a year outside them.
  defp supported_range do
    quote location: :keep do
      # A year outside the supported years is refused before any new moon
      # is sought (see "Supported years").
      defp supported_year!(year) when is_integer(year) and year not in @supported_years,
        do: raise(out_of_range(year))

      defp supported_year!(year), do: year

      defp out_of_range(value) do
        Calendrical.UnsupportedDateRangeError.exception(
          calendar: __MODULE__,
          value: value,
          range: @supported_years
        )
      end
    end
  end

  # The figures a lunar date is written with, and the date they name.
  defp written do
    quote location: :keep do
      @doc """
      Returns the figures a date is written with: its year, its
      traditional month and its day.

      ### Arguments

      * `year` is a year of this calendar.

      * `month` is an ordinal month of the year.

      * `day` is a day of the month.

      ### Returns

      * `{year, traditional_month, day}`, the traditional month an integer
        or `{month, :leap}` for a leap month.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, _month, day} = #{inspect(__MODULE__)}.written_date(today.year, today.month, today.day)
          iex> {year, day} == {today.year, today.day}
          true
      """
      @impl true
      def written_date(year, month, day) do
        Calendrical.Base.Written.lunisolar_written_date(__MODULE__, year, month, day)
      end

      @doc """
      Returns the date of this calendar that written figures name: the
      inverse of `written_date/3`.

      ### Arguments

      * `year` is a year of this calendar.

      * `lunar_month` is a traditional month, or `{month, :leap}`.

      * `day` is a day of the month.

      ### Returns

      * `{:ok, {year, month, day}}` with the ordinal month.

      * `{:error, :invalid_date}` for figures that name no date, an atom as
        `c:Calendrical.date_from_written_date/3` answers.

      ### Examples

          iex> {:ok, today} = Date.convert(~D[2024-06-01], #{inspect(__MODULE__)})
          iex> {year, month, day} = #{inspect(__MODULE__)}.written_date(today.year, today.month, today.day)
          iex> #{inspect(__MODULE__)}.date_from_written_date(year, month, day)
          {:ok, {today.year, today.month, today.day}}
      """
      @impl true
      # A year outside the supported years names no date, as any other
      # figures that name none.
      def date_from_written_date(year, _lunar_month, _day)
          when is_integer(year) and year not in @supported_years,
          # Localize's date parser reads this atom (see c:Calendrical.date_from_written_date/3).
          # credo:disable-for-next-line Calendrical.Credo.ErrorTuple
          do: {:error, :invalid_date}

      def date_from_written_date(year, lunar_month, day) do
        Calendrical.Base.Written.date_from_lunisolar_written_date(
          __MODULE__,
          year,
          lunar_month,
          day
        )
      end
    end
  end

  @doc false
  # The calendar years whose lunar year begins in the Gregorian years
  # given: year 1 begins in the Gregorian year of the epoch, and the years
  # run on without a gap.
  def supported_years(%Date{} = epoch, first..last//1) do
    %Date{year: epoch_year} = Date.convert!(epoch, Calendar.ISO)
    (first - epoch_year + 1)..(last - epoch_year + 1)//1
  end

  @doc false
  def refuse_unknown_options!(options, known_options) do
    case Keyword.keys(options) -- known_options do
      [] ->
        :ok

      unknown ->
        raise Calendrical.UnknownOptionError,
          maker: Calendrical.Calendar.Lunisolar,
          options: unknown,
          known_options: known_options
    end
  end
end
