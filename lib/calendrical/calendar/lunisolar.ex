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

  ### Examples

      defmodule Chinese do
        use Calendrical.Calendar.Lunisolar,
          epoch: ~D[-2636-02-15],
          location: &__MODULE__.location/1

        def location(_iso_days), do: {39.9, 116.4, 44, 8 / 24}
      end

  """

  @known_options [:epoch, :location, :cldr_calendar_type, :era_calendar_type]

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
      end,
      traditional_dates(),
      kernel()
    ]
  end

  # A date from a traditional month, the Gregorian date of a lunar date and
  # the new year of a Gregorian year.
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

      * `{:ok, date}` with the date in this calendar, or `{:error, reason}`.

      """
      def new(year, lunar_month, day) do
        with {:ok, {year, month, day}} <-
               Lunisolar.ordinal_date(year, lunar_month, day, epoch(), @location) do
          {:ok, %Date{year: year, month: month, day: day, calendar: __MODULE__}}
        end
      end

      @doc """
      Returns a date of this calendar from a year, a traditional lunar
      month and a day, raising for what is no date (see `new/3`).

      """
      def new!(year, lunar_month, day) do
        case new(year, lunar_month, day) do
          {:ok, date} -> date
          {:error, reason} -> raise ArgumentError, "cannot build date, reason: #{inspect(reason)}"
        end
      end

      @doc """
      Returns whether a month of a year is the leap month.

      """
      def leap_month?(year, month) do
        Lunisolar.leap_month?(year, month, epoch(), @location)
      end

      @doc """
      Returns the Gregorian date of a traditional lunar month and day in
      the lunar year that begins in a Gregorian year.

      ### Arguments

      * `gregorian_year` is a Gregorian year.

      * `lunar_month` is a traditional month, 1 to 12, or `{month, :leap}`.

      * `lunar_day` is a day of the month.

      ### Returns

      * A `t:Date.t/0` in `Calendar.ISO`.

      """
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

      """
      def new_year_for_gregorian_year(gregorian_year) do
        gregorian_date_for_lunar(gregorian_year, 1, 1)
      end
    end
  end

  # The kernel from `Calendrical.Lunisolar`.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp kernel do
    quote location: :keep do
      @doc """
      Returns whether a year has thirteen months.

      """
      @impl Calendar
      def leap_year?(year) do
        Lunisolar.leap_year?(year, epoch(), @location)
      end

      @doc """
      Returns the position of the year's leap month, or `nil`.

      """
      @impl true
      def leap_month(year) do
        Lunisolar.leap_month(year, epoch(), @location)
      end

      @doc false
      @impl true
      def date_to_iso_days(year, month, day)
          when is_integer(year) and is_integer(month) and is_integer(day) do
        Lunisolar.date_to_iso_days(year, month, day, epoch(), @location)
      end

      @doc false
      @impl true
      def date_from_iso_days(iso_days) do
        Lunisolar.date_from_iso_days(iso_days, epoch(), @location)
      end

      @doc """
      Returns whether a year, month and day are a date of this calendar.

      """
      @impl true
      def valid_date?(year, month, day) do
        Lunisolar.valid_date?(year, month, day, epoch(), @location)
      end

      @doc """
      Returns the number of days in a month of a year, 29 or 30.

      """
      @impl true
      def days_in_month(year, month) do
        Lunisolar.days_in_month(year, month, epoch(), @location)
      end

      @doc """
      Returns the number of whole years, quarters, months, weeks or days
      from one date to another, the months counted through the leap
      months of the years between.

      """
      @impl true
      def diff(from, to, date_part) do
        Calendrical.Base.Common.diff(__MODULE__, from, to, date_part, &months_between/3)
      end

      defp months_between(_calendar, from, to),
        do: Lunisolar.months_between(from, to, epoch(), @location)

      @doc """
      Returns the figures a date is written with: its year, its
      traditional month and its day.

      """
      @impl true
      def written_date(year, month, day) do
        Calendrical.Base.Written.lunisolar_written_date(__MODULE__, year, month, day)
      end

      @doc """
      Returns the date of this calendar that written figures name: the
      inverse of `written_date/3`.

      """
      @impl true
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
  def refuse_unknown_options!(options, known_options) do
    case Keyword.keys(options) -- known_options do
      [] ->
        :ok

      unknown ->
        raise ArgumentError,
              "unknown options #{inspect(unknown)} for use Calendrical.Calendar.Lunisolar; " <>
                "the options are #{inspect(known_options)}"
    end
  end
end
