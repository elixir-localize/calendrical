defmodule Calendrical do
  @moduledoc """
  Calendar functions for calendars compatible with
  Elixir's `Calendar` behaviour.

  `Calendrical` supports the creation of calendars
  that are variations on the proleptic Calendrical.Gregorian
  calendar. It also adds additional functions, defined
  by the `Calendrical` behaviour, to support these
  derived calendars.

  The common purpose of these derived calendars is
  to support the creation and use of financial year
  calendars that are commonly used in business.

  There are two general types of calendars supported:

  * `month` calendars that mirror the monthly structure
    of the proleptic `Calendrical.Gregorian` calendar but which are
    deemed to start the year in a month other than January.

  * `week` calendars that are defined to have a 52 week
    structure (53 weeks in a long year). These calendars
    can be configured to start or end on the first, last or
    nearest day to the beginning or end of a `Calendrical.Gregorian`
    month.  The main intent behind this structure is to
    have each year start and end on the same day of the
    week with a consistent 13-week quarterly structure than
    enables a more straight forware comparison with
    same-period-last-year financial performance.

  """

  alias Calendrical.Config
  alias Calendrical.Compiler
  alias Calendrical.Interval

  import Kernel, except: [inspect: 1, inspect: 2]

  # Whether to coerce valid date with plus/3 for
  # years and months (days, weeks dont ever require
  # cercion).
  @default_coercion true

  @typedoc """
  Specifies the type of a calendar.

  A calendar is a module that implements
  the `Calendar` and `Calendrical`
  behaviours. Calendar functions will
  default to `Calendrical.Gregorian`
  in most cases.

  """
  @type calendar :: module() | nil

  @typedoc """
  Specifies the type of a calendar

  """
  @type calendar_type :: :month | :week

  @typedoc """
  All date fields are optional however many functions
  will require the presence of one or more - and
  often all - fields be present.
  """
  @type date :: %{
          optional(:year) => year(),
          optional(:month) => month(),
          optional(:day) => day(),
          optional(:calendar) => calendar(),
          optional(any) => any()
        }

  @typedoc """
  All time fields are optional however many functions
  will require the presence of one or more - and
  often all - fields be present.
  """
  @type time :: %{
          optional(:calendar) => Calendar.calendar(),
          optional(:hour) => Calendar.hour(),
          optional(:microsecond) => Calendar.microsecond(),
          optional(:minute) => Calendar.minute(),
          optional(:second) => Calendar.second(),
          optional(any) => any()
        }

  @typedoc """
  All naive date time fields are optional however many functions
  will require the presence of one or more - and
  often all - fields be present.
  """
  @type naive_date_time :: %{
          optional(:calendar) => calendar(),
          optional(:day) => day(),
          optional(:hour) => Calendar.hour(),
          optional(:microsecond) => Calendar.microsecond(),
          optional(:minute) => Calendar.minute(),
          optional(:month) => month(),
          optional(:second) => Calendar.second(),
          optional(:year) => year(),
          optional(any) => any()
        }

  @typedoc """
  All date time fields are optional however many functions
  will require the presence of one or more - and
  often all - fields be present.
  """
  @type date_time :: %{
          optional(:calendar) => calendar(),
          optional(:day) => day(),
          optional(:hour) => Calendar.hour(),
          optional(:microsecond) => Calendar.microsecond(),
          optional(:minute) => Calendar.minute(),
          optional(:month) => month(),
          optional(:second) => Calendar.second(),
          optional(:std_offset) => Calendar.std_offset(),
          optional(:time_zone) => Calendar.time_zone(),
          optional(:utc_offset) => Calendar.utc_offset(),
          optional(:year) => year(),
          optional(:zone_abbr) => Calendar.zone_abbr(),
          optional(any) => any()
        }

  @typedoc """
  Super type of any date or time.

  """
  @type any_date_time :: date() | time() | naive_date_time() | date_time()

  @typedoc """
  Specifies the year of a date as either
  a positive integer or nil.
  """
  @type era :: non_neg_integer() | nil

  @typedoc """
  Specifies the year of a date as either
  a positive integer or nil.
  """
  @type year :: Calendar.year() | nil

  @typedoc """
  Specifies the month of a date as either
  a positive integer or nil.
  """
  @type month :: Calendar.month() | nil

  @typedoc """
  Specifies the day of a date as either
  a positive integer or nil.
  """
  @type day :: Calendar.day() | nil

  @typedoc """
  Specifies the quarter of year for a calendar date.

  """
  @type quarter :: 1..4

  @typedoc """
  Specifies the week of year for a calendar date.

  """
  @type week :: pos_integer()

  @typedoc """
  Represents the number of days since the
  calendar epoch.

  The Calendar epoch is `0000-01-01`
  in the proleptic gregorian calendar.

  """
  @type iso_day_number :: integer()

  @typedoc """
  Specifies the days of the week as integers.

  Days of the week are encoded as the integers `1` through
  `7` with `1` representing Monday and 7 representing Sunday.

  Note that a calendar can be configured to start
  on any day of the week. `day_of_week` is only a
  way of encoding the days as an integer.
  """
  @type day_of_week :: 1..7

  @typedoc """
  A mapping of a day of the week ordinal to the
  localized string of the name of that day.

  """
  @type day_of_week_to_binary :: {day_of_week, String.t()}

  @typedoc """
  Boolean indicating is this is a leap month

  """
  @type leap_month? :: boolean()

  @typedoc """
  The precision for date intervals
  """
  @type precision :: :years | :quarters | :months | :weeks | :days

  @typedoc """
  The types of relationship between two Date.Range intervals
  """
  @type interval_relation ::
          :precedes
          | :preceded_by
          | :meets
          | :met_by
          | :overlaps
          | :overlapped_by
          | :finished_by
          | :finishes
          | :contains
          | :during
          | :starts
          | :started_by
          | :equals

  @typedoc """
  The part of a date, time or datetime that can be
  localized.

  """
  @valid_parts [:era, :quarter, :month, :day_of_week, :days_of_week, :am_pm, :day_periods]
  type = &Enum.reduce(&1, fn x, acc -> {:|, [], [x, acc]} end)

  @type part :: unquote(type.(@valid_parts))

  @doc """
  Returns the `month` for a given `year`, `month` or `week`, and `day`
  for a a calendar.

  The `month_of_year` is calculated based upon the calendar configuration.

  """
  @callback month_of_year(
              year :: year(),
              month :: month() | Calendrical.week(),
              day :: day()
            ) ::
              Calendar.month() | {Calendar.month(), leap_month?()}

  @doc """
  Returns a tuple of `{year, week_in_year}` for a given `year`, `month` or `week`, and `day`
  for a a calendar.

  The `week_in_year` is calculated based upon the calendar configuration.

  """
  @callback week_of_year(
              year :: year(),
              month :: month() | Calendrical.week(),
              day :: day()
            ) ::
              {Calendar.year(), Calendar.week()} | {:error, :not_defined}

  @doc """
  Returns a tuple of `{year, week_in_year}` for a given `year`, `month` or `week`, and `day`
  for a a calendar.

  The `iso_week_of_year` is calculated based on the ISO calendar.

  """
  @callback iso_week_of_year(
              year :: year(),
              month :: month() | Calendrical.week(),
              day :: day()
            ) ::
              {Calendar.year(), Calendar.week()} | {:error, :not_defined}

  @doc """
  Returns a tuple of `{month, week_in_month}` for a given `year`, `month` or `week`, and `day`
  for a a calendar.

  The `week_in_month` is calculated based upon the calendar configuration.

  """
  @callback week_of_month(year(), Calendrical.week(), day()) ::
              {Calendar.month(), Calendrical.week()} | {:error, :not_defined}

  @doc """
  Returns the CLDR calendar type.

  Only algorithmic calendars are considered
  in this implementation.
  """
  @callback cldr_calendar_type() ::
              :gregorian
              | :persian
              | :coptic
              | :ethiopic
              | :ethiopic_amete_alem
              | :chinese
              | :japanese
              | :dangi
              | :islamic
              | :islamic_civil
              | :islamic_rgsa
              | :islamic_tbla
              | :islamic_umalqura
              | :hebrew
              | :buddhist
              | :roc
              | :indian

  @doc """
  Returns the calendar basis.

  Returns either `:week` or `:month`.
  """
  @callback calendar_base() :: :week | :month

  @doc """
  Returns the number of periods (which are
  months in a month calendar and weeks in a
  week calendar) in a year

  """
  @callback periods_in_year(year :: year()) :: week() | Calendar.month()

  @doc """
  Returns the number of weeks in a year.

  """
  @callback weeks_in_year(year :: year()) ::
              {Calendrical.week(), Calendar.day()} | {:error, :not_defined}

  @doc """
  Returns the number of days in a year.

  """
  @callback days_in_year(year :: year()) :: Calendar.day()

  @doc """
  Returns the number of days in a month (withoout a year).

  """
  @callback days_in_month(month :: month()) ::
              Calendar.day() | {:ambiguous, Range.t() | [pos_integer()]} | {:error, :undefined}

  @doc """
  Returns a the year in a calendar year.

  """
  @callback calendar_year(year :: year(), month :: month(), day :: day()) ::
              Calendar.year()

  @doc """
  Returns a the extended year in a calendar year.

  """
  @callback extended_year(year :: year(), month :: month(), day :: day()) ::
              Calendar.year()

  @doc """
  Returns a the related year in a calendar year.

  """
  @callback related_gregorian_year(year :: year(), month :: month(), day :: day()) ::
              Calendar.year()

  @doc """
  Returns a the cyclic year in a calendar year.

  """
  @callback cyclic_year(year :: year(), month :: month(), day :: day()) ::
              Calendar.year()

  @doc """
  Returns a date range representing the days in a
  calendar year.

  """
  @callback year(year :: year()) ::
              Date.Range.t() | {:error, :not_defined}

  @doc """
  Returns a date range representing the days in a
  given quarter for a calendar year.

  """
  @callback quarter(year :: year(), quarter :: Calendrical.quarter()) ::
              Date.Range.t() | {:error, :not_defined}

  @doc """
  Returns a date range representing the days in a
  given month for a calendar year.

  """
  @callback month(year :: year(), month :: month()) ::
              Date.Range.t() | {:error, :not_defined}

  @doc """
  Returns a date range representing the days in a
  given week for a calendar year.

  """
  @callback week(year :: year(), week :: week()) ::
              Date.Range.t() | {:error, :not_defined}

  @doc """
  Increments a `t:Date.t/0` or `Date.Range.t` by a specified positive
  or negative integer number of periods (year, quarter, month,
  week or day).

  Calendars need only implement this callback for `:months` and `:quarters`
  since all other date periods can be derived.

  """
  @callback plus(
              year :: year(),
              month :: month() | week(),
              day :: day(),
              months_or_quarters :: :months | :quarters,
              increment :: integer,
              options :: Keyword.t()
            ) :: {Calendar.year(), Calendar.month(), Calendar.day()}

  @days [1, 2, 3, 4, 5, 6, 7]
  @days_in_a_week Enum.count(@days)
  @the_world Localize.Territory.the_world()
  @valid_precision [:years, :quarters, :months, :weeks, :days]
  @default_calendar Calendrical.Gregorian

  alias Localize.LanguageTag
  alias Calendrical.Config

  @doc false
  defguard is_full_date(date)
           when is_map_key(date, :year) and is_map_key(date, :month) and is_map_key(date, :day)

  @doc false
  defguard is_locale_reference(locale) when is_binary(locale) or is_atom(locale)

  @doc false
  def cldr_backend_provider(_config) do
    # No-op: backend provider architecture has been removed.
    # Calendar modules are defined directly, not via backend compilation.
    nil
  end

  @doc false
  def default_coercion do
    @default_coercion
  end

  @doc false
  def default_cldr_calendar do
    default_calendar().cldr_calendar_type()
  end

  @doc """
  Returns the default calendar.

  """
  def default_calendar do
    @default_calendar
  end

  @doc """
  Returns the date of the astronomical Paschal Full Moon for a given Gregorian year.

  The Paschal Full Moon is the first astronomical full moon that occurs on or after
  the March (vernal) equinox. It is the basis for calculating the date of Easter:
  Easter Sunday is the first Sunday after the Paschal Full Moon.

  Note that this function returns the *astronomical* Paschal Full Moon, which is
  computed from observed lunar and solar positions. This may occasionally differ
  by a day or more from the *ecclesiastical* Paschal Full Moon used by the
  Western (Gregorian) and Eastern (Julian) Christian churches, which is defined
  by tabular computus rules rather than astronomical observation.

  The returned date is in UTC.

  ### Arguments

  * `gregorian_year` is the Gregorian year for which to compute the Paschal Full
    Moon. Must be in the range `1000..3000` due to the underlying equinox
    calculation precision.

  ### Returns

  * `{:ok, date}` where `date` is the `t:Date.t/0` of the Paschal Full Moon in UTC, or

  * `{:error, {module, reason}}` if the calculation cannot be performed.

  ### Examples

      iex> Calendrical.paschal_full_moon(2024)
      {:ok, ~D[2024-03-25]}

      iex> Calendrical.paschal_full_moon(2025)
      {:ok, ~D[2025-04-13]}

  """
  @spec paschal_full_moon(Calendar.year()) ::
          {:ok, Date.t()} | {:error, Exception.t()}
  def paschal_full_moon(gregorian_year)
      when is_integer(gregorian_year) and gregorian_year in 1000..3000 do
    with {:ok, equinox} <- Astro.equinox(gregorian_year, :march),
         {:ok, full_moon} <-
           Astro.date_time_lunar_phase_at_or_after(equinox, Astro.Lunar.full_moon_phase()) do
      {:ok, DateTime.to_date(full_moon)}
    end
  end

  @doc """
  Returns the calendar module preferred for
  a territory.

  ### Arguments

  * `territory` is any valid ISO3166-2 code as
    an `t:String.t/0` or upcased `atom`.

  ### Returns

  * `{:ok, calendar_module}` or

  * `{:error, exception}` where `exception` is an exception struct

  ### Examples

      iex> Calendrical.calendar_from_territory(:US)
      {:ok, Calendrical.US}

      iex> {:error, %Localize.UnknownTerritoryError{}} = Calendrical.calendar_from_territory(:YY)

  ### Notes

  The overwhelming majority of territories have
  `:gregorian` as their first preferred calendar
  and therefore `Calendrical.Gregorian` or
  a derivation of it will be returned for most
  territories.

  Returning any other calendar module would require:

  1. That another calendar is preferred over `:gregorian`
     for a territory

  2. That a calendar module is available to support
     that calendar.

  As an example, Iran (territory `:IR`) prefers the
  `:persian` calendar. If the optional library
  [ex_cldr_calendars_persian](https://hex.pm/packages/ex_cldr_calendars_persian)
  is installed, the calendar module `Calendrical.Persian` will
  be returned. If it is not installed, `Calendrical.Gregorian`
  will be returned as `:gregorian` is the second preference
  for `:IR`.

  """
  def calendar_from_territory(territory) do
    Calendrical.Preference.calendar_from_territory(territory)
  end

  @doc """
  Return the calendar module for a locale.

  ### Arguments

  * `locale` is any locale or locale name validated
    by `Localize.validate_locale/1`.  The default is
    `Localize.get_locale()` which returns the locale
    set for the current process.

  ### Returns

  * `{:ok, calendar_module}` or

  * `{:error, exception}` where `exception` is an exception struct

  ### Examples

      iex> Calendrical.calendar_from_locale("en-US")
      {:ok, Calendrical.US}

      iex> Calendrical.calendar_from_locale("en-GB-u-ca-gregory")
      {:ok, Calendrical.GB}

      iex> Calendrical.calendar_from_locale("fa-IR")
      {:ok, Calendrical.Persian}

      iex> Calendrical.calendar_from_locale("fa-IR-u-ca-gregory")
      {:ok, Calendrical.Persian}

  """
  def calendar_from_locale(%LanguageTag{} = locale) do
    Calendrical.Preference.calendar_from_locale(locale)
  end

  def calendar_from_locale(locale) when is_locale_reference(locale) do
    with {:ok, locale} <- Localize.validate_locale(locale) do
      Calendrical.Preference.calendar_from_locale(locale)
    end
  end

  @doc """
  Creates a new proleptic gregrian calendar based upon the
  provided configuration.

  If a module exists with the `calendar_module` name then it
  is returned, not recreated.

  ### Arguments

  * `calendar_module` is an atom representing the module
    name of the created calendar.

  * `calendar_type` is an atom of either `:month` or
    `:week` indicating which type of calendar is to
    be created.

  * `config` is a Keyword list defining the configuration
    of the calendar.

  ### Returns

  * `{:ok, module}` where `module` is the new calendar
    module that conforms to the `Calendar` and `Calendrical`
    behaviours or

  * `{:module_already_exists, module}` if a module of the given
    calendar name already exists. It is not guaranteed
    that the module is in fact a calendar module in this case.

  ## Configuration options

  The following options can be provided to create
  a new calendar.

  * `:weeks_in_month` defines the layout of
    weeks in a quarter for a week- or month-
    based calendar. The value must be one of
    `[4, 4, 5]`, `[4,5,4]` or `[5,4,4]`.
    The default is `[4,4,5]`. This option
    is ignored for `:month` based calendars
    that have the parameter `day_of_year: :first`.

  * `:begins_or_ends` determines whether the calendar
    year begins or ends on the given `:day_of_week` and
    `:month_of_year`. The default is `:begins`.

  * `:first_or_last` determines whether the calendar
    year starts (or ends) on the first, last or nearest
    `:day-of_week` and `:month_of_year`. The default
    is `:first`

  * `:day_of_week` determines the day
    of the week on which this calendar begins
    or ends. It may be a number in the range
    `1..7` representing Monday to Sunday.
    It may also be `:first` indicating the
    the weeks are calculated from the first
    day of the calendar day irrespective of
    the day of the week. In this case the last
    week of the year may be less than 7 days
    in length. The default is `1`.

  * `:month_of_year` determines the `Calendrical.Gregorian`
    month of year in which this calendar begins
    or ends. The default is `1`.

  * `:year` is used to determine which calendar
    Gregogian year is applicable for a given
    calendar date. The valid options are `:first`,
    `:last` and `:majority`.  The default is
    `:majority`.

  * `:min_days_in_first_week` is used to determine
    how many days of the `Calendrical.Gregorian` year must be in
    the first week of a calendar year. This is used
    when determining when the year starts for week-based
    years.  The default is `4` which is consistent with
    the [ISO Week calendar](https://en.wikipedia.org/wiki/ISO_week_date)

  ### Examples

  Each calendar has a function `__config__/0` generated within
  it and therefore the configuration of the included calendars
  in `ex_cldr_calendars` provide insight into the behaviour
  of the configuration parameters.

  As an example here we define the [ISO Week calendar](https://en.wikipedia.org/wiki/ISO_week_date)
  calendar in full:

  ```
  defmodule ISOWeek do
    use Calendrical.Base.Week,
      day_of_week: 1,              # Weeks begin or end on Monday
      month_of_year: 1,            # Years begin or end in January
      min_days_in_first_week: 4,   # 4 Calendrical.Gregorian days of the year must be in the first week
      begins_or_ends: :begins,     # The year *begins* on the `day_of_week` and `month_of_year`
      first_or_last: :first,       # They year *begins* on the *first* `day_of_week` and `month_of_year`
      weeks_in_month: [4, 4, 5],   # The weeks are laid out as *months* in a `[4,4,5]` pattern
      year: :majority,             # Any given year is that in which the majority of Calendrical.Gregorian months fall
      locale: nil                  # No `locale` is used to aid configuration
  end
  ```

  This can be generated at runtime by:

      iex> {_, MyISOWeek} = Calendrical.new MyISOWeek, :week,
      ...>   day_of_week: 1,
      ...>   month_of_year: 1,
      ...>   min_days_in_first_week: 4,
      ...>   begins_or_ends: :begins,
      ...>   first_or_last: :first,
      ...>   weeks_in_month: [4, 4, 5],
      ...>   year: :majority

  Note that `Calendrical.ISOWeek` is included as part of this
  library.

  """
  @spec new(module(), calendar_type(), Keyword.t()) ::
          {:ok, calendar()} | {:module_already_exists, module()} | {:error, String.t()}

  def new(calendar_module, calendar_type, config)
      when is_atom(calendar_module) and calendar_type in [:week, :month] do
    if Code.ensure_loaded?(calendar_module) do
      {:module_already_exists, calendar_module}
    else
      Compiler.create_calendar(calendar_module, calendar_type, config)
    end
  end

  @doc """
  Returns a calendar configured according to
  the preferences defined for a territory.

  """
  def calendar_for_territory(territory, config \\ []) do
    with {:ok, territory} <- Localize.validate_territory(territory) do
      calendar_name = Module.concat(__MODULE__, territory)

      config =
        config
        |> Keyword.put_new(:min_days_in_first_week, min_days_for_territory(territory))
        |> Keyword.put_new(:day_of_week, first_day_for_territory(territory))

      cond do
        same_as_default?(config) -> {:ok, Calendrical.default_calendar()}
        calendar_module?(calendar_name) -> {:ok, calendar_name}
        true -> Compiler.create_calendar(calendar_name, :month, config)
      end
    end
  end

  @doc """
  Returns a boolean indicating if a module
  is a `Calendrical` module.

  """
  def calendar_module?(module) when is_atom(module) do
    Code.ensure_loaded?(module) &&
      function_exported?(module, :cldr_calendar_type, 0)
  end

  @doc false
  def same_as_default?(config) do
    config = Config.extract_options(config)

    default_calendar_config =
      Calendrical.default_calendar().__config__()
      |> Map.put(:calendar, nil)

    config == default_calendar_config
  end

  @doc """
  Converts a date or a date range to another calendar.

  If the argument is a `t:Date.t/0`, `Date.convert/2` is used to
  do the conversion.

  If the argument is a `t:/Date.Range.t/0` then `Date.convert/2` is
  applied to the start and end of the range and a new range returned.

  ### Arguments

  * `date_or_range` is any `t:Date.t/0` or ` t:Date.Range.t/0`.

  * `calendar` is any valid calendar module.

  ### Returns

  * `{:ok, converted_date_or_range}` or

  * `{:error, :incompatible_calendars}`

  ### Example

  """
  @doc since: "2.4.0"
  @spec convert(Date.t() | Date.Range.t(), Calendar.calendar()) ::
          {:ok, Date.t() | Date.Range.t()} | {:error, :incompatible_calendars}

  def convert(%Date{} = date, calendar) do
    Date.convert(date, calendar)
  end

  def convert(%Date.Range{first: first, last: last, step: step}, calendar) do
    with {:ok, new_first} <- Date.convert(first, calendar),
         {:ok, new_last} <- Date.convert(last, calendar) do
      {:ok, Date.range(new_first, new_last, step)}
    end
  end

  @doc """
  Formats the given date, time, or datetime into a string.

  This function is a thin wrapper around `Calendar.strftime/3` intended
  to ease formatting for localized calendars. Localized strings will
  be automatically injected as options to `Calendar.strftime/3`.

  See `Calendar.strftime/3` for details of formatting strings and
  other options.

  Examples:

      iex> Calendrical.strftime(~D[2025-01-26 Calendrical.IL], "%a", locale: :he)
      "יום ב׳"

  """
  def strftime(date_or_time_or_datetime, format, options \\ []) do
    calendar = Map.get(date_or_time_or_datetime, :calendar)
    options = Keyword.merge(options, calendar: calendar)
    strftime_options = strftime_options!(options)

    Calendar.strftime(date_or_time_or_datetime, format, strftime_options)
  end

  @doc """
  Returns a keyword list of options than can be applied to
  `Calendar.strftime/3` or `Calendrical.strftime/3`.

  `strftime_options!` returns a keyword list than can be used as
  options to return localised names for days, months and am/pm.

  ## Arguments

  * `options` is a set of keyword options. The default is `[]`.

  ## Options

  * `:locale` is any locale returned by `Localize.known_locale_names/1`. The
    default is `Localize.get_locale/0`.

  * `:calendar` is the name of any known calendar. The default
    is `Calendrical.Gregorian`.

  ## Example

      iex: Calendrical.strftime_options!()
      [
        am_pm_names: #Function<0.32021692/1 in Calendrical.strftime_options/2>,
        month_names: #Function<1.32021692/1 in Calendrical.strftime_options/2>,
        abbreviated_month_names: #Function<2.32021692/1 in Calendrical.strftime_options/2>,
        day_of_week_names: #Function<3.32021692/1 in Calendrical.strftime_options/2>,
        abbreviated_day_of_week_names: #Function<4.32021692/1 in Calendrical.strftime_options/2>
      ]

  ## Typical usage

      iex> Calendar.strftime(~D[2025-01-26 Calendrical.IL], "%a",
      ...>   Calendrical.strftime_options!(calendar: Calendrical.IL, locale: "en"))
      "Mon"

  """
  def strftime_options!(options \\ []) do
    locale = Keyword.get(options, :locale, Localize.get_locale())
    calendar = Keyword.get(options, :calendar, @default_calendar)

    calendar_type =
      if function_exported?(calendar, :cldr_calendar_type, 0),
        do: calendar.cldr_calendar_type(),
        else: :gregorian

    with {:ok, locale} <- Localize.validate_locale(locale) do
      [
        am_pm_names: fn period ->
          day_periods = unwrap!(Localize.Calendar.day_periods(locale, calendar_type))

          get_in(day_periods, [:format, :abbreviated, period, :default]) ||
            get_in(day_periods, [:format, :abbreviated, period])
        end,
        month_names: fn month ->
          months = unwrap!(Localize.Calendar.months(locale, calendar_type))
          get_in(months, [:format, :wide, month])
        end,
        abbreviated_month_names: fn month ->
          months = unwrap!(Localize.Calendar.months(locale, calendar_type))
          get_in(months, [:format, :abbreviated, month])
        end,
        day_of_week_names: fn day ->
          days = unwrap!(Localize.Calendar.days(locale, calendar_type))
          get_in(days, [:format, :wide, day])
        end,
        abbreviated_day_of_week_names: fn day ->
          days = unwrap!(Localize.Calendar.days(locale, calendar_type))
          get_in(days, [:format, :abbreviated, day])
        end
      ]
    else
      {:error, %{__exception__: true} = exception} -> raise exception
    end
  end

  @doc """
  Returns the cardinal day number representing
  Monday

  """
  @spec monday :: 1
  def monday, do: 1

  @doc """
  Returns the cardinal day number representing
  Tuesday.

  """
  @spec tuesday :: 2
  def tuesday, do: 2

  @doc """
  Returns the cardinal day number representing
  Wednesday.

  """
  @spec wednesday :: 3
  def wednesday, do: 3

  @doc """
  Returns the cardinal day number representing
  Thursday.

  """
  @spec thursday :: 4
  def thursday, do: 4

  @doc """
  Returns the cardinal day number representing
  Friday.

  """
  @spec friday :: 5
  def friday, do: 5

  @doc """
  Returns the cardinal day number representing
  Saturday.

  """
  @spec saturday :: 6
  def saturday, do: 6

  @doc """
  Returns the cardinal day number representing
  Sunday.

  """
  @spec sunday :: 7
  def sunday, do: 7

  @doc """
  Returns the first date of a `year`
  in a `calendar`.

  ### Arguments

  * `year` is any year.

  * `calendar` is any module that implements
    the `Calendar` and `Calendrical`
    behaviours.

  ### Returns

  * a `t:Date.t/0`  or

  * `{:error, :invalid_date}`

  ### Examples

      iex> Calendrical.first_day_of_year(2019, Calendrical.Gregorian)
      %Date{calendar: Calendrical.Gregorian, day: 1, month: 1, year: 2019}

      iex> Calendrical.first_day_of_year(2019, Calendrical.NRF)
      %Date{calendar: Calendrical.NRF, day: 1, month: 1, year: 2019}

  """
  @spec first_day_of_year(year :: year(), calendar :: calendar()) ::
          Date.t() | {:error, :invalid_date}

  def first_day_of_year(year, calendar) do
    with {:ok, date} <- Date.new(year, 1, 1, calendar) do
      date
    end
  end

  @doc """
  Returns the first date of a `year`
  for a `t:Date.t/0`.

  ### Arguments

  * `date` is any `t:Date.t/0`.

  ### Returns

  * a `t:Date.t/0`  or

  * `{:error, :invalid_date}`

  ### Examples

      iex>  Calendrical.first_day_of_year(~D[2019-12-01])
      ~D[2019-01-01]

  """
  @spec first_day_of_year(date :: date()) :: Date.t() | {:error, :invalid_date}

  def first_day_of_year(%Date{year: year, calendar: calendar}) do
    first_day_of_year(year, calendar)
  end

  def first_day_of_year(%{} = date) do
    {year, _month, _day, calendar} = extract_date(date)
    first_day_of_year(year, calendar)
  end

  @doc """
  Returns the last date of a `year`
  for a `calendar`.

  ### Arguments

  * `year` is any year.

  * `calendar` is any module that implements
    the `Calendar` and `Calendrical`
    behaviours

  ### Returns

  * a `t:Date.t/0`  or

  * `{:error, :invalid_date}`

  ### Examples

      iex> Calendrical.last_day_of_year(2019, Calendrical.Gregorian)
      %Date{calendar: Calendrical.Gregorian, day: 31, month: 12, year: 2019}

      iex> Calendrical.last_day_of_year(2019, Calendrical.NRF)
      %Date{calendar: Calendrical.NRF, day: 7, month: 52, year: 2019}

  """
  @spec last_day_of_year(year :: year(), calendar :: calendar()) :: Date.t()

  def last_day_of_year(year, Calendar.ISO) do
    last_month = Calendar.ISO.months_in_year(year)
    last_day = Calendar.ISO.days_in_month(year, last_month)

    with {:ok, date} <- Date.new(year, last_month, last_day) do
      date
    end
  end

  def last_day_of_year(year, calendar) do
    iso_days = calendar.last_gregorian_day_of_year(year)

    with {year, month, day} <- calendar.date_from_iso_days(iso_days),
         {:ok, date} <- Date.new(year, month, day, calendar) do
      date
    end
  end

  @doc """
  Returns the last date of a `year`
  for a `t:Date.t/0`.

  ### Arguments

  * `date` is any `t:Date.t/0`.

  ### Returns

  * a `t:Date.t/0`  or

  * `{:error, :invalid_date}`

  ### Examples

      iex>  Calendrical.last_day_of_year(~D[2019-01-01])
      ~D[2019-12-31]

  """
  @spec last_day_of_year(date :: date()) :: Date.t()

  def last_day_of_year(%Date{year: year, calendar: calendar}) do
    last_day_of_year(year, calendar)
  end

  def last_day_of_year(%{} = date) do
    {year, _month, _day, calendar} = extract_date(date)
    last_day_of_year(year, calendar)
  end

  @doc """
  Returns the gregorian date of the first day of of a `year`
  for a `calendar`.

  ### Arguments

  * `year` is any integer year number.

  * `calendar` is any module that implements the `Calendar` and
    `Calendrical` behaviours or `Calendar.ISO`

  ### Examples

      iex> Calendrical.first_gregorian_day_of_year(2019, Calendrical.Gregorian)
      %Date{calendar: Calendrical.Gregorian, day: 1, month: 1, year: 2019}

      iex> Calendrical.first_gregorian_day_of_year(2019, Calendrical.NRF)
      %Date{calendar: Calendrical.Gregorian, day: 3, month: 2, year: 2019}

      iex> Calendrical.first_gregorian_day_of_year(~D[2019-12-01])
      ~D[2019-01-01]

  """
  @spec first_gregorian_day_of_year(year() | date(), calendar()) ::
          Date.t() | {:error, :invalid_date}

  def first_gregorian_day_of_year(%Date{year: year, calendar: Calendar.ISO}) do
    year
    |> first_gregorian_day_of_year(Calendrical.Gregorian)
    |> Map.put(:calendar, Calendar.ISO)
  end

  def first_gregorian_day_of_year(%{} = date) do
    {year, _month, _day, calendar} = extract_date(date)
    first_gregorian_day_of_year(year, calendar)
  end

  def first_gregorian_day_of_year(year, calendar) do
    {year, month, day} =
      year
      |> calendar.first_gregorian_day_of_year()
      |> Calendrical.Gregorian.date_from_iso_days()

    with {:ok, date} <- Date.new(year, month, day, Calendrical.Gregorian) do
      date
    end
  end

  @doc """
  Returns the gregorian date of the first day of a `year`
  for a `calendar`.

  ### Arguments

  * `year` is any integer year number or a `t:date/0`.

  * `calendar` is any module that implements the `Calendar` and
    `Calendrical` behaviours or `Calendar.ISO`.

  ### Examples

      iex> Calendrical.last_gregorian_day_of_year(2019, Calendrical.Gregorian)
      %Date{calendar: Calendrical.Gregorian, day: 31, month: 12, year: 2019}

      iex> Calendrical.last_gregorian_day_of_year(2019, Calendrical.NRF)
      %Date{calendar: Calendrical.Gregorian, day: 1, month: 2, year: 2020}

      iex> Calendrical.last_gregorian_day_of_year(~D[2019-12-01])
      ~D[2019-12-31]

  """
  @spec last_gregorian_day_of_year(date() | year(), calendar()) ::
          Date.t() | {:error, :invalid_date}

  def last_gregorian_day_of_year(%Date{year: year, calendar: Calendar.ISO}) do
    year
    |> last_gregorian_day_of_year(Calendrical.Gregorian)
    |> Map.put(:calendar, Calendar.ISO)
  end

  def last_gregorian_day_of_year(%{} = date) do
    {year, _month, _day, calendar} = extract_date(date)
    last_gregorian_day_of_year(year, calendar)
  end

  def last_gregorian_day_of_year(year, calendar) when is_integer(year) do
    {year, month, day} =
      year
      |> calendar.last_gregorian_day_of_year()
      |> Calendrical.Gregorian.date_from_iso_days()

    with {:ok, date} <- Date.new(year, month, day, Calendrical.Gregorian) do
      date
    end
  end

  @doc """
  Returns the `{year_of_era, era}` for
  a `date`.

  *This function differs slightly
  from `Date.year_of_era/1`. See the notes
  below*

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * a the year since the start of the era and
    the era of the year as a tuple.

  ### Notes

  1. Unlike `Date.year_of_era/1`, this function supports
    eras that change part way through the calendar
    year. This is common in the Japanese calendar where
    the eras change when a new emperor is ordained which
    can happen at any time of year. Therefore this
    function is consistent with `Date.year_of_era/1` for
    the Gregorian and related calendars, but returns a
    different (and more accurate) result for the Japanese
    calendar.

  2. This is also true for fiscal year calendars that
    start on a day other than January 1st. The year of
    era will depend on whether the calendar was configured
    with `year: :beginning`, `year: :ending` or `year: :majority`.

  ### Examples

      iex> Calendrical.year_of_era(~D[2019-01-01])
      {2019, 1}

      iex> Calendrical.year_of_era(Calendrical.first_day_of_year(2019, Calendrical.NRF))
      {2019, 1}

      iex> Calendrical.year_of_era(Calendrical.last_day_of_year(2019, Calendrical.NRF))
      {2019, 1}

  """
  @spec year_of_era(date()) :: {Calendar.day(), Calendar.era()} | {:error, Exception.t()}

  def year_of_era(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.year_of_era(year, month, day)
  end

  @doc """
  Returns the `{day_of_era, era}` for
  a `date`.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * a the days since the start of the era and
    the era of the year as a tuple.

  ### Examples

      iex> Calendrical.day_of_era ~D[2019-01-01]
      {737060, 1}

      iex> Calendrical.day_of_era(Calendrical.first_day_of_year(2019, Calendrical.NRF))
      {737093, 1}

      iex> Calendrical.day_of_era(Calendrical.last_day_of_year(2019, Calendrical.NRF))
      {737456, 1}

  """
  @spec day_of_era(date()) :: {Calendar.day(), Calendar.era()} | {:error, Exception.t()}

  def day_of_era(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.day_of_era(year, month, day)
  end

  @doc """
  Returns the ISO day of week for a `date`
  where `1` means `Monday` and `7` means
  `Sunday`.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * An integer ISO day of week in the range
    `1..7` where `1` is `Monday` and `7` is
    `Sunday`.

  ### Examples

      iex> {:ok, us_calendar} = Calendrical.calendar_from_locale("en")
      iex> {:ok, us_date} = Date.new(2025, 1, 1, us_calendar)
      iex> Calendrical.iso_day_of_week(us_date)
      3

  """
  @spec iso_day_of_week(date()) :: Calendar.day_of_week()

  def iso_day_of_week(date) do
    date
    |> Date.convert!(Calendar.ISO)
    |> Date.day_of_week(:monday)
  end

  @doc """
  Returns the Modified Julian Day of
  a `t:Date.t/0`.

  ### Arguments

  * `date_or_datetime` is any `t:Date.t/0` or a `t:DateTime.t/0`.
    If a `t:DateTime.t/0` is given, the result will be given in
    the current timezone.

  ### Returns

  * an number representing the
    Modified Julian Day of the `date`.

  ### Notes

  The Modified Julian Day is the number of days
  since November 17, 1858. Therefore this function
  only returns valid values for dates after this
  date.

  ### Examples

      iex> Calendrical.modified_julian_day(~D[2019-01-01])
      58484.0

      iex> Calendrical.modified_julian_day(~U[2019-01-01 12:00:00Z])
      58484.5

      iex> Calendrical.modified_julian_day(~U[2022-09-26 18:00:00.000Z])
      59848.75

      # If the given DateTime is not UTC, the result is given in
      # the local timezone. This example requires a time zone database
      # such as `tz` or `tzdata` to be configured.
      #
      #     dt = DateTime.shift_zone!(~U[2019-01-01 14:00:00Z], "America/Sao_Paulo")
      #     #=> #DateTime<2019-01-01 12:00:00-02:00 -02 America/Sao_Paulo>
      #     Calendrical.modified_julian_day(dt)
      #     #=> 58484.5

  """
  @mjd_epoch_in_iso_days 678_941
  def modified_julian_day(%DateTime{} = datetime) do
    date = DateTime.to_date(datetime)
    {seconds, _microseconds} = datetime |> DateTime.to_time() |> Time.to_seconds_after_midnight()

    mjd_from_date_and_seconds(date, seconds)
  end

  def modified_julian_day(%Date{} = date) do
    mjd_from_date_and_seconds(date, 0)
  end

  defp mjd_from_date_and_seconds(date, seconds) do
    mjd_integer_part = date_to_iso_days(date) - @mjd_epoch_in_iso_days
    mjd_offset = seconds * 1000 / :timer.hours(24)

    mjd_integer_part + mjd_offset
  end

  @doc """
  Returns the DateTime (defaulting to UTC timezone)
  for the given Modified Julian Day.

  ### Arguments

  * `mjd` is a number representing days passed since November 17, 1858 (Julian Calendar)

  ### Returns

  * a `t:DateTime.t/0` at UTC timezone.

  ### Examples

      iex> Calendrical.datetime_from_modified_julian_date(59848)
      ~U[2022-09-26 00:00:00.000Z]

      iex> Calendrical.datetime_from_modified_julian_date(59848.75)
      ~U[2022-09-26 18:00:00.000Z]

  """
  @mjd_epoch_in_mjd 678_576
  @unix_epoch_fixed 719_163
  def datetime_from_modified_julian_date(mjd) when is_number(mjd) do
    # fixed date conversion taken from Calixir library
    mjd_fixed = mjd + @mjd_epoch_in_mjd
    day_in_ms = :timer.hours(24)
    unix = day_in_ms * (mjd_fixed - @unix_epoch_fixed)

    DateTime.from_unix!(trunc(unix), :millisecond)
  end

  @doc """
  Returns the `year` number for
  a `date` that is the representation
  used for a calendar.

  The calendar year may be different the
  the year in the struct. The struct year
  is designed for convertability and for
  date/time arithmetic.

  The representation in rendered calendar
  may be different. For example, in the Chinese
  calendar the cardinal year since epoch is
  stored in the struct but the calendar
  year used for representation is the
  sexigesimal year (a number between 1 and 60).

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * the calendar year as an
    integer.

  ### Examples

      iex> Calendrical.calendar_year(~D[2019-01-01])
      2019

      iex> Calendrical.calendar_year(Calendrical.first_day_of_year(2019, Calendrical.NRF))
      2019

      iex> Calendrical.calendar_year(Calendrical.last_day_of_year(2019, Calendrical.NRF))
      2019

  """
  @spec calendar_year(date()) :: Calendar.year() | {:error, Exception.t()}

  def calendar_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.calendar_year(year, month, day)
  end

  @doc """
  Returns the extended `year` number for
  a `date`.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * the extended calendar year as an
    integer.

  ### Examples

      iex> Calendrical.extended_year(~D[2019-01-01])
      2019

      iex> Calendrical.extended_year(Calendrical.first_day_of_year(2019, Calendrical.NRF))
      2019

      iex> Calendrical.extended_year(Calendrical.last_day_of_year(2019, Calendrical.NRF))
      2019

  """
  @spec extended_year(date()) :: Calendar.year() | {:error, Exception.t()}

  def extended_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.extended_year(year, month, day)
  end

  @doc """
  Returns the related gregorian `year`
  number for a `date`.

  A related gregorian year is the gregorian
  year that is most closely associated with a
  date that is in another calendar.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * the related gregorian year as an
    integer.

  ### Examples

      iex> Calendrical.related_gregorian_year ~D[2019-01-01]
      2019

      iex> Calendrical.related_gregorian_year(Calendrical.first_day_of_year(2019, Calendrical.NRF))
      2019

      iex> Calendrical.related_gregorian_year(Calendrical.last_day_of_year(2019, Calendrical.NRF))
      2019

  """
  @spec related_gregorian_year(date()) :: Calendar.year() | {:error, Exception.t()}

  def related_gregorian_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.related_gregorian_year(year, month, day)
  end

  @doc """
  Returns the cycle `year`
  number for a `date`.

  A related gregorian year is the gregorian
  year that is most closely associated with a
  date that is in another calendar.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * the cyclic year as an integer.

  ### Examples

      iex> Calendrical.cyclic_year(~D[2019-01-01])
      2019

      iex> Calendrical.cyclic_year(Calendrical.first_day_of_year(2019, Calendrical.NRF))
      2019

      iex> Calendrical.cyclic_year(Calendrical.last_day_of_year(2019, Calendrical.NRF))
      2019

  """
  @spec cyclic_year(date()) :: Calendar.year() | {:error, Exception.t()}

  def cyclic_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.cyclic_year(year, month, day)
  end

  @doc """
  Returns the `quarter` number for
  a `date`.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * a the quarter of the year as an
    integer

  ### Examples

      iex> Calendrical.quarter_of_year(~D[2019-01-01])
      1

      iex> Calendrical.quarter_of_year(Calendrical.first_day_of_year(2019, Calendrical.NRF))
      1

      iex> Calendrical.quarter_of_year(Calendrical.last_day_of_year(2019, Calendrical.NRF))
      4

  """
  @spec quarter_of_year(date()) :: Calendrical.quarter() | {:error, Exception.t()}

  def quarter_of_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.quarter_of_year(year, month, day)
  end

  @doc """
  Returns the `month` number for
  a `date`.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * the month of the year as an
    integer

  ### Examples

      iex> Calendrical.month_of_year(~D[2019-01-01])
      1
      iex> Calendrical.month_of_year(~D[2019-12-01])
      12
      iex> Calendrical.month_of_year(~D[2019-52-01 Calendrical.NRF])
      12
      iex> Calendrical.month_of_year(~D[2019-26-01 Calendrical.NRF])
      6

  """
  @spec month_of_year(date()) ::
          Calendar.month()
          | {Calendar.month(), leap_month :: :leap}
          | {:error, Exception.t()}

  def month_of_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.month_of_year(year, month, day)
  end

  @doc """
  Returns the `{year, week_number}`
  for a `date`.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * a the week of the year as an
    integer or

  * `{:error, :not_defined}` if the calendar
    does not support the concept of weeks.

  ### Examples

      iex> Calendrical.week_of_year(~D[2019-01-01])
      {2019, 1}
      iex> Calendrical.week_of_year(~D[2019-12-01])
      {2019, 48}
      iex> Calendrical.week_of_year(~D[2019-52-01 Calendrical.NRF])
      {2019, 52}
      iex> Calendrical.week_of_year(~D[2019-26-01 Calendrical.NRF])
      {2019, 26}
      iex> Calendrical.week_of_year(~D[2019-12-01 Calendrical.Julian])
      {:error, :not_defined}

  """
  @spec week_of_year(date()) :: {Calendar.year(), week()} | {:error, Exception.t()}

  def week_of_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.week_of_year(year, month, day)
  end

  @doc """
  Returns the `ISO week` number for
  a `date`.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * a the ISO week of the year as an
    integer or

  * `{:error, :not_defined}` is the calendar
    does not support the concept of weeks.

  ### Examples

      iex> Calendrical.iso_week_of_year(~D[2019-01-01])
      {2019, 1}
      iex> Calendrical.iso_week_of_year(~D[2019-02-01])
      {2019, 5}
      iex> Calendrical.iso_week_of_year(~D[2019-52-01 Calendrical.NRF])
      {2020, 4}
      iex> Calendrical.iso_week_of_year(~D[2019-26-01 Calendrical.NRF])
      {2019, 30}
      iex> Calendrical.iso_week_of_year(~D[2019-12-01 Calendrical.Julian])
      {:error, :not_defined}

  """
  @spec iso_week_of_year(date()) :: {Calendar.year(), week()} | {:error, Exception.t()}

  def iso_week_of_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.iso_week_of_year(year, month, day)
  end

  @doc """
  Returns the `{month, week_number}`
  for a `date`.

  The nature of a week depends on the
  calendar configuration and therefore
  some results may be surprising.  For example
  the date of December 31st 2018 is actually
  in month one of the ISO Week calendar of
  2019.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * a tuple of the form `{month, week}` or

  * `{:error, :not_defined}` if the calendar
    does not support the concept of weeks.

  ### Examples

      iex> Calendrical.week_of_month(~D[2019-01-01])
      {1, 1}
      iex> Calendrical.week_of_month(~D[2018-12-31])
      {1, 1}
      iex> Calendrical.week_of_month(~D[2019-01-01 Calendrical.BasicWeek])
      {1, 1}
      iex> Calendrical.week_of_month(~D[2018-12-31 Calendrical.BasicWeek])
      {12, 5}
      iex> Calendrical.week_of_month(~D[2018-12-31 Calendrical.Julian])
      {:error, :not_defined}

  """
  @spec week_of_month(date()) :: {Calendar.month(), week()} | {:error, Exception.t()}

  def week_of_month(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.week_of_month(year, month, day)
  end

  @doc """
  Returns the `day` of the year
  for a `date`.

  ### Arguments

  * `date` is any `t:Date.t/0` or a map with one or
    more of the fields `:year`, `:month`, `:day` and
    optionally `:calendar`.

  ### Returns

  * a the day of the year as an
    integer

  ### Examples

      iex> Calendrical.day_of_year(~D[2019-01-01])
      1

      iex> Calendrical.day_of_year(~D[2016-12-31])
      366

      iex> Calendrical.day_of_year(~D[2019-12-31])
      365

      iex> Calendrical.day_of_year(~D[2019-52-07 Calendrical.NRF])
      365

      iex> Calendrical.day_of_year(~D[2012-53-07 Calendrical.NRF])
      372

  """
  @spec day_of_year(date()) :: Calendar.day() | {:error, Exception.t()}

  def day_of_year(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.day_of_year(year, month, day)
  end

  @doc """
  Returns the number of weeks in a year.

  ### Arguments

  * `date` is any `t:Date.t/0` or an integer year
    or a map with one or more of the fields `:year`,
    `:month`, `:day` and optionally `:calendar`.

  ### Returns

  * `{weeks_in_year, days_in_last_week}`

  ### Examples

      # For the default Calendar.ISO calendar the number of
      # weeks in a year is either 52 or 53 with each week
      # being 7 days. The first week may start in the Gregorian
      # year prior and end in the following Gregorian year.

      iex> Calendrical.weeks_in_year(~D[2022-01-01])
      {52, 7}

      iex> Calendrical.weeks_in_year(~D[2023-01-01])
      {53, 7}

      # For week calculations, the Calendrical.ISO and Calendrical.ISOWeek
      # have the same definition.

      iex> Calendrical.weeks_in_year(2023, Calendrical.ISO)
      {52, 7}

      iex> Calendrical.weeks_in_year(2020, Calendrical.ISOWeek)
      {53, 7}

      iex> Calendrical.weeks_in_year(~D[2026-W01-1 Calendrical.ISOWeek])
      {53, 7}

      # For calendars that are configured to have the first week
      # start on the first day of the year there will be a final
      # week 53 with either 1 or 2 days.

      iex> Calendrical.SequentialWeeks.weeks_in_year(2023)
      {53, 1}

      iex> Calendrical.SequentialWeeks.weeks_in_year(2020)
      {53, 2}

  """
  @spec weeks_in_year(date()) ::
          {Calendrical.week(), Calendar.day_of_week()} | {:error, Exception.t()}
  def weeks_in_year(%{} = date) do
    {year, _month, _day, calendar} = extract_date(date)
    calendar.weeks_in_year(year)
  end

  @spec weeks_in_year(year(), calendar) ::
          {Calendrical.week(), Calendar.day_of_week()} | {:error, Exception.t()}
  def weeks_in_year(year, Calendar.ISO) do
    Calendrical.Gregorian.weeks_in_year(year)
  end

  def weeks_in_year(year, calendar) do
    calendar.weeks_in_year(year)
  end

  @doc """
  Returns whether a given date is a weekend day.

  Weekend days are locale-specific and depend on
  the policies of a given territory (country).

  ### Arguments

  * `date` is any `t:Date.t/0`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:locale` is any locale or locale name validated
    by `Localize.validate_locale/1`.  The default is
    `Localize.get_locale/0` which returns the locale
    set for the current process.

  * `:territory` is any valid ISO-3166-2 territory
    that is validated by `Localize.validate_territory/1`.

  ### Notes

  When identifying which territory context within which
  to determine whether a given day is a weekend or not
  the following order applies:

  * A territory specified by the `:territory` option.

  * The territory defined as part of the `:locale` option.

  * The territory defined as part of the current processes
    default locale.

  ### Examples

      # The default locale is `en-001` for which
      # the territory is `001` (the world). The weekend
      # for `001` is Saturday and Sunday
      iex> Calendrical.weekend? ~D[2019-03-23]
      true

      iex> Calendrical.weekend?(~D[2019-03-23], locale: :en)
      true

      iex> Calendrical.weekend?(~D[2019-03-23], territory: "IS")
      true

      # In India the official weekend is only Sunday
      iex> Calendrical.weekend?(~D[2019-03-23], locale: "en-IN")
      false

      # In Israel the weekend starts on Friday
      iex> Calendrical.weekend?(~D[2019-03-22], locale: :he)
      true

      iex> Calendrical.weekend?(~D[2019-03-22 Calendrical.IL], locale: :he)
      true

      # As it also does in Saudia Arabia
      iex> Calendrical.weekend?(~D[2019-03-22], locale: :"ar-SA")
      true

      # Sunday is not a weekend day in Saudi Arabia
      iex> Calendrical.weekend?(~D[2019-03-24], locale: :"ar-SA")
      false

  """
  @spec weekend?(date(), Keyword.t()) :: boolean | {:error, Exception.t()}

  def weekend?(date, options \\ []) do
    locale = Keyword.get(options, :locale, Localize.get_locale())

    with {:ok, locale} <- Localize.validate_locale(locale),
         {:ok, default_territory} <- Localize.Territory.territory_from_locale(locale),
         territory = Keyword.get(options, :territory, default_territory),
         {:ok, territory} <- Localize.validate_territory(territory) do
      iso_day_of_week(date) in weekend(territory)
    end
  end

  @doc """
  Returns whether a given date is a weekday.

  Weekdays are locale-specific and depend on
  the policies of a given territory (region, country).

  ### Arguments

  * `date` is any `t:Date.t/0`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:locale` is any locale or locale name validated
    by `Localize.validate_locale/1`.  The default is
    `Localize.get_locale/0` which returns the locale
    set for the current process.

  * `:territory` is any valid ISO-3166-2 territory
    that is validated by `Localize.validate_territory/1`.

  ### Notes

  When identifying which territory context within which
  to determine whether a given day is a weekday or not
  the following order applies:

  * A territory specified by the `:territory` option.

  * The territory defined as part of the `:locale` option.

  * The territory defined as part of the current processes
    default locale.

  ### Examples

      # The default locale is `en-001` for which
      # the territory is `001` (the world). The weekdays
      # for `001` are Monday to Friday
      iex> Calendrical.weekday?(~D[2019-03-23], locale: :en)
      false

      iex> Calendrical.weekday?(~D[2019-03-23], territory: "IS")
      false

      # Saturday is a weekday in India
      iex> Calendrical.weekday?(~D[2019-03-23], locale: :"en-IN")
      true

      # Friday is not a weekday in Saudi Arabia
      iex> Calendrical.weekday?(~D[2019-03-22], locale: :"ar-SA")
      false

      # Friday is not a weekday in Israel
      iex> Calendrical.weekday?(~D[2019-03-22], locale: :he)
      false

      iex> Calendrical.weekday?(~D[2019-03-22 Calendrical.IL], locale: :he)
      false

  """
  @spec weekday?(date(), Keyword.t()) :: boolean | {:error, Exception.t()}

  def weekday?(date, options \\ []) do
    locale = Keyword.get(options, :locale, Localize.get_locale())

    with {:ok, locale} <- Localize.validate_locale(locale),
         {:ok, default_territory} <- Localize.Territory.territory_from_locale(locale),
         territory = Keyword.get(options, :territory, default_territory),
         {:ok, territory} <- Localize.validate_territory(territory) do
      iso_day_of_week(date) in weekdays(territory)
    end
  end

  @doc """
  Returns the first day of a week for a given
  locale where `1` means `Monday` and `7` means `Sunday`.

  Note that the first day of the first week is commonly
  not aligned with the first day of the year.

  """
  def first_day_for_locale(%LanguageTag{} = locale) do
    with {:ok, territory} <- Localize.Territory.territory_from_locale(locale) do
      first_day_for_territory(territory)
    end
  end

  def first_day_for_locale(locale, _options \\ []) when is_locale_reference(locale) do
    with {:ok, locale} <- Localize.validate_locale(locale) do
      first_day_for_locale(locale)
    end
  end

  @doc """
  Returns the minimum days in the first week of a year
  for a given locale.

  """
  def min_days_for_locale(%LanguageTag{} = locale) do
    with {:ok, territory} <- Localize.Territory.territory_from_locale(locale) do
      min_days_for_territory(territory)
    end
  end

  def min_days_for_locale(locale, _options \\ []) when is_locale_reference(locale) do
    with {:ok, locale} <- Localize.validate_locale(locale) do
      min_days_for_locale(locale)
    end
  end

  @doc """
  Returns a list of the days of the week that
  are considered a weekend for a given
  territory (region, country).

  ### Arguments

  * `territory` is any valid ISO3166-2 code.

  ### Returns

  * A list of integers representing the days of
    the week that are weekend days. Here `1` means
    `Monday` and `7` means `Sunday`.

  ### Examples

      iex> Calendrical.weekend("US")
      [6, 7]

      iex> Calendrical.weekend("IN")
      [7]

      iex> Calendrical.weekend("SA")
      [5, 6]

      iex> {:error, %Localize.UnknownTerritoryError{}} = Calendrical.weekend("yy")

  """
  def weekend(territory)

  @doc """
  Returns a list of the days of the week that
  are considered a weekend for a given
  territory (country).

  ### Arguments

  * `territory` is any valid ISO3166-2 code.

  ### Returns

  * A list of integers representing the days of
    the week that are week days. Here `1` means
    `Monday` and `7` means `Sunday`.

  ### Notes

  The list of days may not be monotonic. See
  the example for Saudi Arabia below.

  ### Examples

      iex> Calendrical.weekdays("US")
      [1, 2, 3, 4, 5]

      iex> Calendrical.weekdays("IN")
      [1, 2, 3, 4, 5, 6]

      iex> Calendrical.weekdays("SA")
      [1, 2, 3, 4, 7]

      iex> {:error, %Localize.UnknownTerritoryError{}} = Calendrical.weekdays("yy")

  """
  def weekdays(territory)

  @doc """
  Returns the first day of the week for a
  given territory.

  ### Arguments

  * `territory` is any valid ISO3166-2 code.

  ### Returns

  * The first day of the week for this territory.
    Here `1` means `Monday` and `7` means `Sunday`.

  """
  def first_day_for_territory(territory)

  @week_info Localize.SupplementalData.weeks()

  for territory <- Localize.SupplementalData.known_territories() do
    starts =
      get_in(@week_info, [:weekend_start, territory]) ||
        get_in(@week_info, [:weekend_start, @the_world])

    ends =
      get_in(@week_info, [:weekend_end, territory]) ||
        get_in(@week_info, [:weekend_end, @the_world])

    first_day =
      get_in(@week_info, [:first_day, territory]) ||
        get_in(@week_info, [:first_day, @the_world])

    min_days =
      get_in(@week_info, [:min_days, territory]) ||
        get_in(@week_info, [:min_days, @the_world])

    def first_day_for_territory(unquote(territory)) do
      unquote(first_day)
    end

    def min_days_for_territory(unquote(territory)) do
      unquote(min_days)
    end

    def weekend(unquote(territory)) do
      unquote(Enum.to_list(starts..ends))
    end

    def weekdays(unquote(territory)) do
      unquote(@days -- Enum.to_list(starts..ends))
    end
  end

  def first_day_for_territory(territory) do
    with {:ok, territory} <- Localize.validate_territory(territory) do
      first_day_for_territory(territory)
    end
  end

  def min_days_for_territory(territory) do
    with {:ok, territory} <- Localize.validate_territory(territory) do
      min_days_for_territory(territory)
    end
  end

  def weekend(territory) do
    with {:ok, territory} <- Localize.validate_territory(territory) do
      weekend(territory)
    end
  end

  def weekdays(territory) do
    with {:ok, territory} <- Localize.validate_territory(territory) do
      weekdays(territory)
    end
  end

  @doc """
  Returns the number of days in `n` weeks

  ## Example

      iex> Calendrical.weeks_to_days(2)
      14

  """
  @spec weeks_to_days(integer) :: integer
  def weeks_to_days(n) do
    trunc(n * @days_in_a_week)
  end

  @doc """
  Formats a date into a string representation.

  Note that the output is not decorated with
  the calendar module name.

  ## Example

      iex> Calendrical.date_to_string(~D[2019-12-04])
      "2019-12-04"

      iex> Calendrical.date_to_string(~D[2019-23-04 Calendrical.NRF])
      "2019-W23-4"

  """
  @spec date_to_string(Date.t()) :: String.t()
  def date_to_string(%{} = date) do
    {year, month, day, calendar} = extract_date(date)
    calendar.date_to_string(year, month, day)
  end

  @doc """
  An `inspect_fun/2` that can be configured in
  `Inspect.Opts` supporting inspection of user-defined
  calendars.

  This function can be configured in `IEx` for Elixir version 1.9
  and later by:

      IEx.configure(inspect: [inspect_fun: &Calendrical.inspect/2])
      :ok

  """
  @spec inspect(term, list()) :: Inspect.Algebra.t()
  def inspect(term, opts \\ [])

  def inspect(%Date{calendar: Calendar.ISO} = date, opts) do
    Kernel.inspect(date, opts)
  end

  def inspect(%Date{calendar: calendar, year: year, month: month, day: day}, opts) do
    calendar.inspect_date(year, month, day, opts)
  end

  def inspect(%Date.Range{first: first, last: last}, _opts) do
    calendar = first.calendar
    "#<DateRange<" <> calendar.inspect_date(first) <> ".." <> calendar.inspect_date(last) <> ">"
  end

  def inspect(term, opts) do
    Kernel.inspect(term, opts)
  end

  @doc """
  Returns the current date or date range for
  a date period (year, quarter, month, week
  or day).

  ### Arguments

  * `date_or_date_range` is any `t:Date.t/0` or
    `Date.Range.t`.

  * `period` is `:year`, `:quarter`, `:month`,
    `:week` or `:day`.

  ### Returns

  When a `t:Date.t/0` is passed, a `t:Date.t/0` is
  returned.  When a `Date.Range.t` is passed
  a `Date.Range.t` is returned.

  ### Examples

      iex> Calendrical.current(~D[2019-01-01], :day)
      ~D[2019-01-01]

  """
  def current(%Date.Range{first: date}, :year) do
    current(date, :year)
    |> Interval.year()
  end

  def current(date, :year) do
    date
  end

  def current(%Date.Range{first: date}, :quarter) do
    current(date, :quarter)
    |> Interval.quarter()
  end

  def current(date, :quarter) do
    date
  end

  def current(%Date.Range{first: date}, :month) do
    current(date, :month)
    |> Interval.month()
  end

  def current(date, :month) do
    date
  end

  def current(%Date.Range{first: date}, :week) do
    current(date, :week)
    |> Interval.week()
  end

  def current(date, :week) do
    date
  end

  def current(%Date.Range{first: date}, :day) do
    current(date, :day)
    |> Interval.day()
  end

  def current(date, :day) do
    date
  end

  @doc """
  Returns the next date or date range for
  a date period (year, quarter, month, week
  or day).

  ### Arguments

  * `date_or_date_range` is any `t:Date.t/0` or
    `Date.Range.t`.

  * `period` is `:year`, `:quarter`, `:month`,
  ` :week` or `:day`.

  ### Returns

  When a `t:Date.t/0` is passed, a `t:Date.t/0` is
  returned.  When a `Date.Range.t` is passed
  a `Date.Range.t` is returned.

  ### Examples

      iex> Calendrical.next(~D[2019-01-01], :day)
      ~D[2019-01-02]

      iex> Calendrical.next(~D[2019-01-01], :month)
      ~D[2019-02-01]

      iex> Calendrical.next(~D[2019-01-01], :quarter)
      ~D[2019-04-01]

      iex> Calendrical.next(~D[2019-01-01], :year)
      ~D[2020-01-01]

  """
  def next(date_or_date_range, date_part, options \\ [])

  def next(%Date.Range{last: date}, :year, options) do
    next(date, :year, options)
    |> Interval.year()
  end

  def next(date, :year, _options) do
    Date.shift(date, year: 1)
  end

  def next(%Date.Range{first: date}, :quarter, options) do
    next(date, :quarter, options)
    |> Interval.quarter()
  end

  def next(date, :quarter, _options) do
    Date.shift(date, month: 3)
  end

  def next(%Date.Range{first: date}, :month, options) do
    next(date, :month, options)
    |> Interval.month()
  end

  def next(date, :month, _options) do
    Date.shift(date, month: 1)
  end

  def next(%Date.Range{last: date}, :week, options) do
    next(date, :week, options)
    |> Interval.week()
  end

  def next(date, :week, _options) do
    Date.shift(date, week: 1)
  end

  def next(%Date.Range{last: date}, :day, options) do
    next(date, :day, options)
    |> Interval.day()
  end

  def next(date, :day, _options) do
    Date.shift(date, day: 1)
  end

  @doc """
  Returns the previous date or date range for
  a date period (year, quarter, month, week
  or day).

  ### Arguments

  * `date_or_date_range` is any `t:Date.t/0` or
    `Date.Range.t`.

  * `period` is `:year`, `:quarter`, `:month`,
    `:week` or `:day`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Returns

  When a `t:Date.t/0` is passed, a `t:Date.t/0` is
  returned.  When a `Date.Range.t` is passed
  a `Date.Range.t` is returned.

  ### Examples

      iex> Calendrical.previous(~D[2019-01-01], :day)
      ~D[2018-12-31]

      iex> Calendrical.previous(~D[2019-01-01], :quarter)
      ~D[2018-10-01]

      iex> Calendrical.previous(~D[2019-01-01], :month)
      ~D[2018-12-01]

      iex> Calendrical.previous(~D[2019-01-01], :year)
      ~D[2018-01-01]

  """
  def previous(date_or_date_range, date_part, options \\ [])

  def previous(%Date.Range{first: date}, :year, options) do
    previous(date, :year, options)
    |> Interval.year()
  end

  def previous(date, :year, _options) do
    Date.shift(date, year: -1)
  end

  def previous(%Date.Range{last: date}, :quarter, options) do
    previous(date, :quarter, options)
    |> Interval.quarter()
  end

  def previous(date, :quarter, _options) do
    Date.shift(date, month: -3)
  end

  def previous(%Date.Range{last: date}, :month, options) do
    previous(date, :month, options)
    |> Interval.month()
  end

  def previous(date, :month, _options) do
    Date.shift(date, month: -1)
  end

  def previous(%Date.Range{first: date}, :week, options) do
    previous(date, :week, options)
    |> Interval.week()
  end

  def previous(date, :week, _options) do
    Date.shift(date, week: -1)
  end

  def previous(%Date.Range{first: date}, :day, options) do
    previous(date, :day, options)
  end

  def previous(date, :day, _options) do
    Date.shift(date, day: -1)
  end

  @doc """
  Localize a date by converting it to calendar
  introspected from the provided or default locale.

  ### Arguments

  * `date` is any `t:Date.t/0`.

  * `options` is a `t:Keyword.t/0` list of options. The default is
    `[]`.

  ### Options

  * `:locale` is any valid locale name in the list returned by
    `Localize.known_locale_names/1` or a `Localize.LanguageTag` struct
    returned by `Localize.Locale.new!/2`. The default is `Localize.get_locale()`.

  ### Returns

  * `{:ok, date}` where `date` is converted into the calendar
    associated with the current or provided locale.

  ### Examples

      iex> Calendrical.localize(~D[2022-06-09], locale: "fr")
      {:ok, %Date{year: 2022, month: 6, day: 9, calendar: Calendrical.FR}}

  """
  @doc since: "1.19.0"

  @spec localize(any_date_time()) ::
          {:ok, any_date_time()}
          | {:error, :incompatible_calendars}
          | {:error, Exception.t()}

  @spec localize(any_date_time(), Keyword.t() | atom()) ::
          {:ok, any_date_time()}
          | {:error, :incompatible_calendars}
          | {:error, Exception.t()}

  @spec localize(any_date_time(), atom(), Keyword.t()) ::
          String.t() | {:error, :incompatible_calendars} | {:error, Exception.t()}

  def localize(date) do
    localize(date, [])
  end

  @doc since: "1.19.0"

  def localize(date, options) when is_list(options) do
    locale = Keyword.get(options, :locale, Localize.get_locale())

    with {:ok, locale} <- Localize.validate_locale(locale),
         {:ok, calendar} <- calendar_from_locale(locale) do
      Date.convert(date, calendar)
    end
  end

  @doc """
  Returns a localized string for a part of
  a `t:Date.t/0`.

  ### Arguments

  * `date` is any `t:Date.t/0`.

  * `part` is one of `:era`, `:quarter`, `:month`,
    `:day_of_week` or `:days_of_week`.

  * `options` is a `t:Keyword.t/0` list of options.

  ### Options

  * `:locale` is any valid locale name in the list returned by
    `Localize.known_locale_names/1` or a `Localize.LanguageTag` struct
    returned by `Localize.Locale.new!/2`. The default is `Localize.get_locale()`.

  * `:format` is one of `:wide`, `:abbreviated` or `:narrow`. The
    default is `:abbreviated`.

  * `:era` will, if set to `:variant` localize the era using
    the variant data. In the `:en` locale, this will produce `CE` and
    `BCE` rather than the default `AD` and `BC`.

  * `:am_pm` will, if set to `:variant` localize the "AM"/"PM"
    time period indicator with the variant data. In the `:en` locale,
    this will produce `am` and `pm` rather than the default `AM` and `PM`.

  ### Returns

  * A string representing the localized date part, or

  * A list of strings representing the days of the week for
    when `part` is `:days_of_week`. The days are in week order for
    the given date's calendar, or

  * `{error, {exception_module, message}}` if an error is detected

  ### Examples

      iex> Calendrical.localize(~D[2019-01-01], :era)
      "AD"

      iex> Calendrical.localize(~D[2019-01-01], :era, era: :variant)
      "CE"

      iex> Calendrical.localize(~D[2019-01-01], :day_of_week)
      "Tue"

      iex> Calendrical.localize(~D[0001-01-01], :day_of_week)
      "Mon"

      iex> Calendrical.localize(~D[2019-01-01], :days_of_week)
      [{1, "Mon"}, {2, "Tue"}, {3, "Wed"}, {4, "Thu"}, {5, "Fri"}, {6, "Sat"}, {7, "Sun"}]

      iex> Calendrical.localize(~D[2019-06-01], :era)
      "AD"

      iex> Calendrical.localize(~D[2019-06-01], :quarter)
      "Q2"

      iex> Calendrical.localize(~D[2019-06-01], :month)
      "Jun"

      iex> Calendrical.localize(~D[2019-06-01], :day_of_week)
      "Sat"

      iex> Calendrical.localize(~D[2019-06-01], :day_of_week, format: :wide)
      "Saturday"

      iex> Calendrical.localize(~D[2019-06-01], :day_of_week, format: :narrow)
      "S"

      iex> Calendrical.localize(~D[2019-06-01], :day_of_week, locale: "ar")
      "السبت"

  """
  @spec localize(datetime :: any_date_time(), part :: part(), options :: Keyword.t()) ::
          String.t() | {:error, Exception.t()}

  def localize(datetime, part, options \\ [])

  def localize(%{calendar: Calendar.ISO} = datetime, part, options) do
    datetime = %{datetime | calendar: Calendrical.Gregorian}
    localize(datetime, part, options)
  end

  def localize(datetime, part, options) do
    locale = Keyword.get(options, :locale, Localize.get_locale())
    type = Keyword.get(options, :type, :format)
    format = Keyword.get(options, :format, :abbreviated)

    with {:ok, locale} <- Localize.validate_locale(locale),
         {:ok, part} <- validate_part(part),
         {:ok, type} <- validate_type(type),
         {:ok, format} <- validate_format(format) do
      localize(datetime, part, type, format, locale, options)
    end
  end

  @doc false
  def localize(datetime, part, type, format, locale, options \\ [])

  def localize(datetime, :era, _type, format, locale, options) do
    calendar = Map.get(datetime, :calendar, @default_calendar)
    calendar_type = calendar.cldr_calendar_type()
    variant? = options[:era] == :variant

    with {_, era} <- day_of_era(datetime) do
      era_key = if variant?, do: -era - 1, else: era
      eras = unwrap!(Localize.Calendar.eras(locale, calendar_type))

      get_in(eras, [format, era_key])
    end
  end

  def localize(datetime, :cyclic_year, type, format, locale, _options) do
    calendar = Map.get(datetime, :calendar, @default_calendar)
    calendar_type = calendar.cldr_calendar_type()

    case cyclic_year(datetime) do
      {:error, reason} ->
        {:error, reason}

      cyclic_year ->
        cyclic_year_data = unwrap!(Localize.Calendar.cyclic_years(locale, calendar_type))

        localized_cyclic_year =
          get_in(cyclic_year_data, [:years, type, format, cyclic_year])

        localized_cyclic_year || to_string(cyclic_year)
    end
  end

  @doc false
  def localize(datetime, :quarter, type, format, locale, _options) do
    calendar_type = datetime.calendar.cldr_calendar_type()

    case quarter_of_year(datetime) do
      {:error, reason} ->
        {:error, reason}

      quarter ->
        quarters = unwrap!(Localize.Calendar.quarters(locale, calendar_type))
        get_in(quarters, [type, format, quarter])
    end
  end

  @doc false
  def localize(datetime, :month, :numeric, _format, locale, _options) do
    calendar = Map.get(datetime, :calendar, @default_calendar)
    calendar_type = calendar.cldr_calendar_type()

    case month_of_year(datetime) do
      month when is_number(month) ->
        month

      {month, :leap} when is_number(month) ->
        month_patterns = unwrap!(Localize.Calendar.month_patterns(locale, calendar_type))

        if month_patterns do
          leap_pattern = get_in(month_patterns, [:numeric, :all, :leap])

          Localize.Substitution.substitute([to_string(month)], leap_pattern)
          |> :erlang.iolist_to_binary()
        else
          to_string(month)
        end

      error ->
        error
    end
  end

  def localize(datetime, :month, type, format, locale, _options) do
    calendar = Map.get(datetime, :calendar, @default_calendar)
    calendar_type = calendar.cldr_calendar_type()

    datetime =
      datetime
      |> Map.put_new(:year, Date.utc_today().year)
      |> Map.put_new(:calendar, calendar)

    months_in_year = months_in_year(datetime)

    case month_of_year(datetime) do
      month when is_number(month) ->
        cardinal_month =
          cardinal_month(month, calendar, months_in_year)

        months_data = unwrap!(Localize.Calendar.months(locale, calendar_type))
        get_in(months_data, [type, format, cardinal_month])

      {month, :leap} when is_number(month) ->
        cardinal_month =
          cardinal_month(month, calendar, months_in_year)

        months_data = unwrap!(Localize.Calendar.months(locale, calendar_type))

        # Calendars such as Hebrew encode the leap-year variant of a
        # month directly in the months data under a `_yeartype_leap`
        # key. Try that first; if no variant exists, fall back to the
        # `month_patterns` substitution mechanism used by lunisolar
        # calendars.
        leap_variant_key = :"#{cardinal_month}_yeartype_leap"
        variant = get_in(months_data, [type, format, leap_variant_key])

        cond do
          is_binary(variant) ->
            variant

          true ->
            month_patterns =
              unwrap!(Localize.Calendar.month_patterns(locale, calendar_type))

            month = get_in(months_data, [type, format, cardinal_month])

            if is_map(month_patterns) do
              leap_pattern = get_in(month_patterns, [type, format, :leap])

              Localize.Substitution.substitute([to_string(month)], leap_pattern)
              |> :erlang.iolist_to_binary()
            else
              month
            end
        end

      error ->
        error
    end
  end

  @doc false
  def localize(datetime, :day_of_week, type, format, locale, _options)
      when is_full_date(datetime) do
    calendar = Map.get(datetime, :calendar, @default_calendar)
    calendar_type = calendar.cldr_calendar_type()

    day = iso_day_of_week(datetime)
    days_data = unwrap!(Localize.Calendar.days(locale, calendar_type))
    get_in(days_data, [type, format, day])
  end

  def localize(date, :day_of_week, _type, _format, _locale, _options) do
    {:error, missing_date_error("localize", date[:year], date[:month], date[:day])}
  end

  @doc false
  def localize(datetime, :days_of_week, type, format, locale, _options) do
    for date <- Interval.week(datetime) do
      day_of_week = day_of_week(date)
      cardinal_day_of_week = iso_day_of_week(date)

      days_data = unwrap!(Localize.Calendar.days(locale, date.calendar.cldr_calendar_type()))

      day_name =
        get_in(days_data, [type, format, cardinal_day_of_week])

      {day_of_week, day_name}
    end
  end

  @doc false
  def localize(%{hour: hour} = time, :am_pm, type, format, locale, options) do
    calendar = Map.get(time, :calendar, @default_calendar)
    calendar_type = calendar.cldr_calendar_type()

    am_pm = am_pm(hour)
    preference = options[:am_pm] || options[:period]
    default_or_variant = if preference == :variant, do: :variant, else: :default
    day_periods = unwrap!(Localize.Calendar.day_periods(locale, calendar_type))
    am_pm = get_in(day_periods, [type, format, am_pm])
    Map.get(am_pm, default_or_variant) || Map.get(am_pm, :default)
  end

  @doc false
  def localize(day_period, :day_periods, type, format, locale, options) do
    calendar = Keyword.get(options, :calendar, @default_calendar)
    calendar_type = calendar.cldr_calendar_type()

    day_periods_data = unwrap!(Localize.Calendar.day_periods(locale, calendar_type))
    get_in(day_periods_data, [type, format, day_period])
  end

  defp am_pm(hour) when hour < 12 or rem(hour, 24) < 12 do
    :am
  end

  defp am_pm(_hour) do
    :pm
  end

  # Get the month of the calendar-specific year as the month
  # in the gregorian calendar (starting in January)
  @doc false
  def cardinal_month(month, calendar, months_in_year) do
    if function_exported?(calendar, :__config__, 0) do
      do_cardinal_month(month, calendar.__config__(), months_in_year)
    else
      month
    end
  end

  defp do_cardinal_month(month, %{month_of_year: 1}, _months_in_year) do
    month
  end

  defp do_cardinal_month(month, %{month_of_year: month_of_year}, months_in_year) do
    Localize.Utils.Math.amod(month + month_of_year - 1, months_in_year)
  end

  # Get the calendar-specific day of the week as the day
  # of the week in Calendar.ISO which starts with 1 == Monday.
  @doc false
  def cardinal_day_of_week(day, calendar) do
    if function_exported?(calendar, :__config__, 0) do
      do_cardinal_day_of_week(day, calendar.__config__())
    else
      day
    end
  end

  def do_cardinal_day_of_week(day, %{day_of_week: 1}) do
    day
  end

  def do_cardinal_day_of_week(day, %{day_of_week: day_of_week}) do
    Localize.Utils.Math.amod(day + day_of_week - 1, @days_in_a_week)
  end

  @doc """
  Returns a sorted list of tuples containing ordinal months and
  month names for a give calendar.

  ### Arguments

  * `calendar` is any calendar module.

  * `options` is a keyword list of options.

  ### Options

  * `:locale` is any locale returned by `Localize.known_locale_names/1`. The
    default is `Localize.get_locale/0`.

  * `:type` is one of `:stand_alone` or `:format`. The default
    is `:format`.

  * `:format` is one of `:abbreviated`, `Lwide` or `:narrow`.
    The default is `:abbreviated`.

  ### Returns

  * A sorted list of tuples of the format `{ordinal month number, month name}`.

  ### Examples

      iex> Calendrical.month_names(Calendar.ISO, format: :wide)
      %{
        1 => "January",
        2 => "February",
        3 => "March",
        4 => "April",
        5 => "May",
        6 => "June",
        7 => "July",
        8 => "August",
        9 => "September",
        10 => "October",
        11 => "November",
        12 => "December"
      }

      iex> Calendrical.month_names(Calendar.ISO, locale: :de)
      %{
        1 => "Jan.",
        2 => "Feb.",
        3 => "März",
        4 => "Apr.",
        5 => "Mai",
        6 => "Juni",
        7 => "Juli",
        8 => "Aug.",
        9 => "Sept.",
        10 => "Okt.",
        11 => "Nov.",
        12 => "Dez."
      }

      iex> Calendrical.month_names(Calendrical.Gregorian, locale: :fr, format: :narrow)
      %{
        1 => "J",
        2 => "F",
        3 => "M",
        4 => "A",
        5 => "M",
        6 => "J",
        7 => "J",
        8 => "A",
        9 => "S",
        10 => "O",
        11 => "N",
        12 => "D"
      }

  """
  @doc since: "2.3.0"

  @spec month_names(calendar :: calendar(), options :: Keyword.t()) ::
          list({pos_integer, String.t()}) | {:error, Exception.t()}

  def month_names(calendar, options \\ [])

  def month_names(Calendar.ISO, options) do
    month_names(Calendrical.Gregorian, options)
  end

  def month_names(calendar, options) do
    locale = Keyword.get(options, :locale, Localize.get_locale())
    type = Keyword.get(options, :type, :format)
    format = Keyword.get(options, :format, :abbreviated)

    calendar_type =
      if function_exported?(calendar, :cldr_calendar_type, 0),
        do: calendar.cldr_calendar_type(),
        else: :gregorian

    with {:ok, locale} <- Localize.validate_locale(locale),
         {:ok, type} <- validate_type(type),
         {:ok, format} <- validate_format(format) do
      month_names = unwrap!(Localize.Calendar.months(locale, calendar_type))
      get_in(month_names, [type, format])
    end
  end

  @valid_parts [:era, :quarter, :month, :day_of_week, :days_of_week, :am_pm, :day_periods]
  defp validate_part(part) do
    if part in @valid_parts do
      {:ok, part}
    else
      {:error, Calendrical.InvalidPartError.exception(part: part, valid_parts: @valid_parts)}
    end
  end

  @valid_types [:format, :stand_alone]
  defp validate_type(type) do
    if type in @valid_types do
      {:ok, type}
    else
      {:error, Calendrical.InvalidTypeError.exception(type: type, valid_types: @valid_types)}
    end
  end

  @valid_formats [:wide, :abbreviated, :narrow]
  defp validate_format(format) do
    if format in @valid_formats do
      {:ok, format}
    else
      {:error,
       Calendrical.InvalidFormatError.exception(format: format, valid_formats: @valid_formats)}
    end
  end

  @doc false
  def month_day(_year, month, day, _calendar, false) do
    {month, day}
  end

  def month_day(year, month, day, calendar, true) do
    new_month =
      year
      |> calendar.periods_in_year
      |> min(month)

    new_day =
      year
      |> calendar.days_in_month(month)
      |> min(day)

    {new_month, new_day}
  end

  @doc false
  def shift_date(year, month, day, calendar, duration) do
    shift_options = shift_date_options(duration)

    Enum.reduce(shift_options, {year, month, day}, fn
      {_, 0}, date ->
        date

      {:year, value}, {year, month, day} ->
        calendar.plus(year, month, day, :years, value)

      {:month, value}, {year, month, day} ->
        calendar.plus(year, month, day, :months, value)

      {:week, value}, {year, month, day} ->
        calendar.plus(year, month, day, :weeks, value)

      {:day, value}, {year, month, day} ->
        calendar.plus(year, month, day, :days, value)
    end)
  end

  @doc false
  def shift_naive_datetime(
        year,
        month,
        day,
        hour,
        minute,
        second,
        microsecond,
        calendar,
        duration
      ) do
    shift_options = shift_datetime_options(duration)

    Enum.reduce(shift_options, {year, month, day, hour, minute, second, microsecond}, fn
      {_, 0}, naive_datetime ->
        naive_datetime

      {:year, value}, {year, month, day, hour, minute, second, microsecond} ->
        {new_year, new_month, new_day} = calendar.plus(year, month, day, :years, value)
        {new_year, new_month, new_day, hour, minute, second, microsecond}

      {:month, value}, {year, month, day, hour, minute, second, microsecond} ->
        {new_year, new_month, new_day} = calendar.plus(year, month, day, :months, value)
        {new_year, new_month, new_day, hour, minute, second, microsecond}

      {time_unit, value}, naive_datetime ->
        shift_time_unit(naive_datetime, calendar, value, time_unit)
    end)
  end

  defp shift_time_unit(
         {year, month, day, hour, minute, second, microsecond},
         calendar,
         value,
         unit
       )
       when unit in [:second, :millisecond, :microsecond, :nanosecond] or is_integer(unit) do
    {value, precision} = shift_time_unit_values(value, microsecond)

    {year, month, day, hour, minute, second, {ms_value, _}} =
      calendar.naive_datetime_to_iso_days(year, month, day, hour, minute, second, microsecond)
      |> shift_time_unit(calendar, value, unit)
      |> calendar.naive_datetime_from_iso_days()

    {year, month, day, hour, minute, second, {ms_value, precision}}
  end

  defp shift_time_unit({hour, minute, second, microsecond}, calendar, value, unit)
       when unit in [:second, :millisecond, :microsecond, :nanosecond] or is_integer(unit) do
    {value, precision} = shift_time_unit_values(value, microsecond)

    {_days, day_fraction} =
      shift_time_unit(
        {0, Calendar.ISO.time_to_day_fraction(hour, minute, second, microsecond)},
        calendar,
        value,
        unit
      )

    {hour, minute, second, {microsecond, _}} = Calendar.ISO.time_from_day_fraction(day_fraction)

    {hour, minute, second, {microsecond, precision}}
  end

  defp shift_time_unit({_days, _day_fraction} = iso_days, _calendar, value, unit)
       when unit in [:second, :millisecond, :microsecond, :nanosecond] or is_integer(unit) do
    ppd = System.convert_time_unit(86400, :second, unit)
    Calendar.ISO.add_day_fraction_to_iso_days(iso_days, value, ppd)
  end

  defp shift_time_unit_values({0, _}, {_, original_precision}) do
    {0, original_precision}
  end

  defp shift_time_unit_values({ms_value, ms_precision}, {_, _}) do
    {ms_value, ms_precision}
  end

  defp shift_time_unit_values(value, {_, original_precision}) do
    {value, original_precision}
  end

  defp shift_date_options(%Duration{
         year: year,
         month: month,
         week: week,
         day: day,
         hour: 0,
         minute: 0,
         second: 0,
         microsecond: {0, 0}
       }) do
    [
      year: year,
      month: month,
      week: week,
      day: day
    ]
  end

  defp shift_date_options(_duration) do
    raise ArgumentError,
          "cannot shift date by time scale unit. Expected :year, :month, :week, :day"
  end

  defp shift_datetime_options(%Duration{
         year: year,
         month: month,
         week: week,
         day: day,
         hour: hour,
         minute: minute,
         second: second,
         microsecond: microsecond
       }) do
    [
      year: year,
      month: month,
      second: week * 7 * 86400 + day * 86400 + hour * 3600 + minute * 60 + second,
      microsecond: microsecond
    ]
  end

  @doc """
  Returns an `Enumerable` list of dates of a given precision
  of either `:years`, `:quarters`, `:months`, `:weeks` or
  `:days`.

  ### Arguments

  * `date_from` is a any `t:Date.t/0` that is the start of the
    sequence.

  * `date_to_or_count` is upper bound of the sequence
    as a `t:Date.t/0` or the number of dates in the
    sequence to be generated.

  * `precision` is one of `:years`, `:quarters`,
    `:months`, `:weeks` or `:days`.

  The sequence is generated starting with `date_from` until the next date
  in the sequence would be after `date_to`.

  ### Notes

  The sequence can be in ascending or descending date order
  based upon whether `date_from` is greater than `date_to`.

  ### Returns

  * A list of dates

  ### Examples

      iex> d = ~D[2019-01-31]
      ~D[2019-01-31]
      iex> d2 = ~D[2019-05-31]
      ~D[2019-05-31]
      iex> Calendrical.interval(d, 3, :months)
      [~D[2019-01-31], ~D[2019-02-28], ~D[2019-03-31]]
      iex> Calendrical.interval(d, d2, :months)
      [~D[2019-01-31], ~D[2019-02-28], ~D[2019-03-31],
       ~D[2019-04-30], ~D[2019-05-31]]

  """
  @spec interval(date_from :: Date.t(), date_to_or_count :: Date.t() | non_neg_integer, precision) ::
          list(Date.t())

  def interval(date_from, count, precision)
      when is_integer(count) and precision in @valid_precision do
    {shift_unit, multiplier} = precision_to_shift(precision)

    for i <- 0..(count - 1) do
      Date.shift(date_from, [{shift_unit, i * multiplier}])
    end
  end

  def interval(date_from, date_to, precision) when precision in @valid_precision do
    if Date.compare(date_from, date_to) == :lt do
      calculate_interval(date_from, date_from, date_to, precision, 1)
    else
      calculate_interval(date_to, date_to, date_from, precision, 1)
      |> Enum.reverse()
    end
  end

  defp calculate_interval(date_origin, date_from, date_to, precision, iteration) do
    if Date.compare(date_from, date_to) in [:lt, :eq] do
      {shift_unit, multiplier} = precision_to_shift(precision)
      next_date = Date.shift(date_origin, [{shift_unit, iteration * multiplier}])
      [date_from | calculate_interval(date_origin, next_date, date_to, precision, iteration + 1)]
    else
      []
    end
  end

  defp precision_to_shift(:years), do: {:year, 1}
  defp precision_to_shift(:quarters), do: {:month, 3}
  defp precision_to_shift(:months), do: {:month, 1}
  defp precision_to_shift(:weeks), do: {:week, 1}
  defp precision_to_shift(:days), do: {:day, 1}

  @doc """
  Returns an a `Stream` function than can be lazily
  enumerated.

  This function has the same arguments and provides
  the same functionality as `interval/3` except that
  it is lazily evaluated.

  ### Arguments

  * `date_from` is a any `t:Date.t/0` that is the start of the
    sequence.

  * `date_to_or_count` is upper bound of the sequence
    as a `t:Date.t/0` or the number of dates in the
    sequence to be generated.

  * `precision` is one of `:years`, `:quarters`,
    `:months`, `:weeks` or `:days`.

  The sequence is generated starting with `date_from` until the next date
  in the sequence would be after `date_to`.

  ### Notes

  The sequence can be in ascending or descending date order
  based upon whether `date_from` is greater than `date_to`.

  ### Returns

  * A list of dates.

  ### Examples

      iex> d = ~D[2019-01-31]
      ~D[2019-01-31]
      iex> d2 = ~D[2019-05-31]
      ~D[2019-05-31]
      iex> Calendrical.interval_stream(d, 3, :months) |> Enum.to_list
      [~D[2019-01-31], ~D[2019-02-28], ~D[2019-03-31]]
      iex> Calendrical.interval_stream(d, d2, :months) |> Enum.to_list
      [~D[2019-01-31], ~D[2019-02-28], ~D[2019-03-31],
       ~D[2019-04-30], ~D[2019-05-31]]

  """
  @spec interval_stream(
          date_from :: Date.t(),
          date_to_or_count :: Date.t() | non_neg_integer,
          precision
        ) :: fun

  def interval_stream(date_from, count, precision)
      when is_integer(count) and precision in @valid_precision do
    Stream.resource(
      fn ->
        {date_from, 0, count, precision}
      end,
      fn {date_from, iteration, count, precision} ->
        if iteration == count do
          {:halt, date_from}
        else
          {shift_unit, multiplier} = precision_to_shift(precision)
          next_date = Date.shift(date_from, [{shift_unit, iteration * multiplier}])
          {[next_date], {date_from, iteration + 1, count, precision}}
        end
      end,
      fn _ ->
        :ok
      end
    )
  end

  def interval_stream(date_from, date_to, precision) do
    if Date.compare(date_from, date_to) == :gt do
      interval_stream_backward(date_from, date_to, precision)
    else
      interval_stream_forward(date_from, date_to, precision)
    end
  end

  defp interval_stream_forward(date_from, date_to, precision)
       when precision in @valid_precision do
    Stream.resource(
      fn ->
        {date_from, date_to, precision, 0}
      end,
      fn {date_from, date_to, precision, iteration} ->
        {shift_unit, multiplier} = precision_to_shift(precision)
        next_date = Date.shift(date_from, [{shift_unit, iteration * multiplier}])

        if Date.compare(next_date, date_to) == :gt do
          {:halt, next_date}
        else
          {[next_date], {date_from, date_to, precision, iteration + 1}}
        end
      end,
      fn _ -> :ok end
    )
  end

  defp interval_stream_backward(date_from, date_to, precision)
       when precision in @valid_precision do
    Stream.resource(
      fn ->
        {date_from, date_to, precision, 0}
      end,
      fn {date_from, date_to, precision, iteration} ->
        {shift_unit, multiplier} = precision_to_shift(precision)
        next_date = Date.shift(date_from, [{shift_unit, -(iteration * multiplier)}])

        if Date.compare(next_date, date_to) == :lt do
          {:halt, next_date}
        else
          {[next_date], {date_from, date_to, precision, iteration + 1}}
        end
      end,
      fn _ -> :ok end
    )
  end

  @doc """
  Returns the number of days since the start
  of the epoch.

  The start of the epoch is the date 0000-01-01.

  ## Argumenets

  * `date` is any `t:Date.t/0`.

  ### Returns

  * The integer number of days since the epoch
    for the given `date`.

  ## Example

      iex> Calendrical.date_to_iso_days(~D[2019-01-01])
      737425

      iex> Calendrical.date_to_iso_days(~D[0001-01-01])
      366

      iex> Calendrical.date_to_iso_days(~D[0000-01-01])
      0

  """
  @spec date_to_iso_days(Date.t()) :: iso_day_number()

  def date_to_iso_days(date) do
    %{year: year, month: month, day: day, calendar: calendar} = date
    calendar.date_to_iso_days(year, month, day)
  end

  @doc """
  Returns a date represented by a number of
  days since the start of the epoch.

  The start of the epoch is the date
  `0000-01-01`.

  ## Argumenets

  * `iso_days` is an integer representing the
    number of days since the start of the epoch.

  * `calendar` is any module that implements
    the `Calendar` and `Calendrical` behaviours.

  ### Returns

  * a `t:Date.t/0`

  ## Example

      iex> Calendrical.date_from_iso_days(737425, Calendar.ISO)
      ~D[2019-01-01]

      iex> Calendrical.date_from_iso_days(366, Calendar.ISO)
      ~D[0001-01-01]

      iex> Calendrical.date_from_iso_days(0, Calendar.ISO)
      ~D[0000-01-01]

  """
  @spec date_from_iso_days(Calendar.iso_days() | iso_day_number, calendar()) ::
          Date.t() | {:error, :incompatible_calendars | :invalid_date}

  def date_from_iso_days({days, _}, calendar) do
    date_from_iso_days(days, calendar)
  end

  def date_from_iso_days(iso_day_number, calendar) do
    {year, month, day} = Calendar.ISO.date_from_iso_days(iso_day_number)

    with {:ok, date} <- Date.new(year, month, day),
         {:ok, date} <- Date.convert(date, calendar) do
      date
    end
  end

  @doc """
  Returns a `t:Date.t/0` from a date tuple of
  `{year, month, day}` and a calendar.

  ### Arguments

  * `{year, month, day}` is a tuple
    representing a date.

  * `calendar` is any module implementing
    the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * a `t:Date.t/0`.

  ### Examples

      iex> Calendrical.date_from_tuple({2019, 3, 25}, Calendrical.Gregorian)
      %Date{calendar: Calendrical.Gregorian, day: 25, month: 3, year: 2019}

      iex> Calendrical.date_from_tuple({2019, 2, 29}, Calendrical.Gregorian)
      {:error, :invalid_date}

  """
  def date_from_tuple({year, month, day}, calendar \\ Calendrical.Gregorian) do
    with {:ok, date} <- Date.new(year, month, day, calendar) do
      date
    end
  end

  @doc """
  Returns a `t:Date.t/0` from a keyword list
  and a calendar.

  ### Arguments

  * `[year: year, month: month, day: day}` is a
    keyword list representing a date.

  * `calendar` is any module implementing
    the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * a `t:Date.t/0` or

  * `{:error, :invalid_date}`

  ### Examples

      iex> Calendrical.date_from_list([year: 2019, month: 3, day: 25], Calendrical.Gregorian)
      %Date{calendar: Calendrical.Gregorian, day: 25, month: 3, year: 2019}

      iex> Calendrical.date_from_list([year: 2019, month: 2, day: 29], Calendrical.Gregorian)
      {:error, :invalid_date}

  """
  def date_from_list([{atom, _value} | _rest] = list, calendar \\ Calendrical.Gregorian)
      when is_atom(atom) do
    with {:ok, year} <- Keyword.fetch(list, :year),
         {:ok, month} <- Keyword.fetch(list, :month),
         {:ok, day} <- Keyword.fetch(list, :day),
         {:ok, date} <- Date.new(year, month, day, calendar) do
      date
    else
      :error -> {:error, :invalid_date}
      other -> other
    end
  end

  @doc """
  Returns a `t:Date.t/0` from a year, day_of_year
  and a calendar.

  ### Arguments

  * `year` is any integer year that is valid in
    `calendar`.

  * `day_of_year` is any valid ordinal day of
    `year`.

  * `calendar` is any module implementing
    the `Calendar` and `Calendrical`
    behaviours. The default is `Calendrical.Gregorian`.

  ### Returns

  * a `t:Date.t/0` or

  * `{:error, :invalid_date}`

  """
  def date_from_day_of_year(year, day_of_year, calendar \\ Calendrical.Gregorian)

  def date_from_day_of_year(year, day_of_year, calendar)
      when is_integer(year) and is_integer(day_of_year) and day_of_year > 0 do
    iso_days = calendar.date_to_iso_days(year, 1, 1) + day_of_year - 1

    if day_of_year <= calendar.days_in_year(year) do
      {year, month, day} = calendar.date_from_iso_days(iso_days)

      with {:ok, date} <- Date.new(year, month, day) do
        date
      end
    else
      {:error, :invalid_date}
    end
  end

  def date_from_day_of_year(_year, _day_of_year, _calendar) do
    {:error, :invalid_date}
  end

  @doc """
  Returns the day of the week for a given
  `iso_day_number`

  ### Arguments

  * `iso_day_number` is the number of days since the start
    of the epoch.  See `Calendrical.date_to_iso_days/1`.

  ### Returns

  * An integer representing a day of the week where Monday
    is represented by `1` and Sunday is represented by `7`.

  ### Examples

      iex> days = Calendrical.date_to_iso_days(~D[2019-01-01])
      iex> Calendrical.iso_days_to_day_of_week(days) == Calendrical.tuesday()
      true

  """
  @spec iso_days_to_day_of_week(Calendar.iso_days() | Calendar.day()) :: day_of_week()
  def iso_days_to_day_of_week({days, _}) do
    iso_days_to_day_of_week(days)
  end

  def iso_days_to_day_of_week(iso_day_number) when is_integer(iso_day_number) do
    Integer.mod(iso_day_number + 6, 7)
  end

  @doc """
  Validates if the argument is a Calendrical
  calendar module.

  If the calendar is `Calendar.ISO` then the
  validated calendar is returned as `Calendrical.Gregorian`.

  ### Arguments

  * `calendar_module` is a module that implements the
    `Calendrical` behaviour.

  ### Returns

  * `{:ok, calendar_module}` or

  * `{:error, exception}` where `exception` is an exception struct

  ### Examples

      iex> Calendrical.validate_calendar(Calendrical.Gregorian)
      {:ok, Calendrical.Gregorian}

      iex> Calendrical.validate_calendar(Calendar.ISO)
      {:ok, Calendrical.Gregorian}

      iex> {:error, %Calendrical.InvalidCalendarModuleError{module: :not_a_calendar}} =
      ...>   Calendrical.validate_calendar(:not_a_calendar)

  """
  def validate_calendar(Calendar.ISO) do
    {:ok, Calendrical.Gregorian}
  end

  def validate_calendar(calendar_module) when is_atom(calendar_module) do
    if Code.ensure_loaded?(calendar_module) &&
         function_exported?(calendar_module, :cldr_calendar_type, 0) do
      {:ok, calendar_module}
    else
      {:error, invalid_calendar_error(calendar_module)}
    end
  end

  def validate_calendar(other) do
    {:error, invalid_calendar_error(other)}
  end

  #
  # Helpers
  #

  defp extract_date(%{} = date) do
    {year, month, day, calendar} =
      {Map.get(date, :year), Map.get(date, :month), Map.get(date, :day), Map.get(date, :calendar)}

    calendar =
      case calendar do
        nil -> Calendrical.Gregorian
        Calendar.ISO -> Calendrical.Gregorian
        calendar -> calendar
      end

    {year, month, day, calendar}
  end

  @doc false
  def invalid_calendar_error(calendar_module) do
    Calendrical.InvalidCalendarModuleError.exception(module: calendar_module)
  end

  ## January starts end the same year, December ends starts the same year
  @doc false
  def start_end_gregorian_years(year, %Config{first_or_last: :first, month_of_year: 1}) do
    {year, year}
  end

  @doc false
  def start_end_gregorian_years(year, %Config{first_or_last: :last, month_of_year: 12}) do
    {year, year}
  end

  ## Majority years
  @doc false
  def start_end_gregorian_years(year, %Config{
        first_or_last: :first,
        year: :majority,
        month_of_year: month
      })
      when month <= 6 do
    {year, year + 1}
  end

  @doc false
  def start_end_gregorian_years(year, %Config{
        first_or_last: :first,
        year: :majority,
        month_of_year: month
      })
      when month > 6 do
    {year - 1, year}
  end

  @doc false
  def start_end_gregorian_years(year, %Config{
        first_or_last: :last,
        year: :majority,
        month_of_year: month
      })
      when month > 6 do
    {year - 1, year}
  end

  @doc false
  def start_end_gregorian_years(year, %Config{
        first_or_last: :last,
        year: :majority,
        month_of_year: month
      })
      when month <= 6 do
    {year, year + 1}
  end

  ## Beginning years
  @doc false
  def start_end_gregorian_years(year, %Config{first_or_last: :last, year: :beginning}) do
    {year - 1, year}
  end

  ## Ending years
  @doc false
  def start_end_gregorian_years(year, %Config{first_or_last: :first, year: :ending}) do
    {year, year + 1}
  end

  @doc false
  def calendar_error(calendar_name) do
    Localize.UnknownCalendarError.exception(calendar: calendar_name)
  end

  @doc false
  def offset_to_string(utc, std, zone, format \\ :extended)
  def offset_to_string(0, 0, "Etc/UTC", _format), do: "Z"

  def offset_to_string(utc, std, _zone, format) do
    total = utc + std
    second = abs(total)
    minute = second |> rem(3600) |> div(60)
    hour = div(second, 3600)
    format_offset(total, hour, minute, format)
  end

  @doc false
  def format_offset(total, hour, minute, :extended) do
    sign(total) <> zero_pad(hour, 2) <> ":" <> zero_pad(minute, 2)
  end

  def format_offset(total, hour, minute, :basic) do
    sign(total) <> zero_pad(hour, 2) <> zero_pad(minute, 2)
  end

  @doc false
  def zone_to_string(0, 0, _abbr, "Etc/UTC"), do: ""
  def zone_to_string(_, _, abbr, zone), do: " " <> abbr <> " " <> zone

  @doc false
  def sign(total) when total < 0, do: "-"
  def sign(_), do: "+"

  @doc false
  def zero_pad(val, count) when val >= 0 do
    num = Integer.to_string(val)
    :binary.copy("0", max(count - byte_size(num), 0)) <> num
  end

  def zero_pad(val, count) do
    "-" <> zero_pad(-val, count)
  end

  @doc false
  def coerce_iso_calendar({:error, :invalid_date}) do
    {:error, :invalid_date}
  end

  def coerce_iso_calendar(%Date.Range{} = range) do
    Date.range(coerce_iso_calendar(range.first), coerce_iso_calendar(range.last))
  end

  def coerce_iso_calendar(date) do
    %{date | calendar: Calendar.ISO}
  end

  @doc false
  def calendar_name(module) when is_atom(module) do
    Kernel.inspect(module)
  end

  @doc false
  @calendars Localize.SupplementalData.calendars()
  def calendars do
    @calendars
  end

  @doc false
  def missing_date_error(function, year, month, day) do
    Calendrical.MissingFieldsError.exception(
      function: function,
      fields: [year: year, month: month, day: day]
    )
  end

  @doc false
  def missing_year_month_error(function, year, month) do
    Calendrical.MissingFieldsError.exception(
      function: function,
      fields: [year: year, month: month]
    )
  end

  @doc false
  def missing_year_error(function, year) do
    Calendrical.MissingFieldsError.exception(function: function, fields: [year: year])
  end

  @doc false
  def missing_month_error(function, month) do
    Calendrical.MissingFieldsError.exception(function: function, fields: [month: month])
  end

  @doc false
  def missing_day_error(function, day) do
    Calendrical.MissingFieldsError.exception(function: function, fields: [day: day])
  end

  defdelegate day_of_week(date), to: Date
  defdelegate day_of_week(date, starting_on), to: Date
  defdelegate days_in_month(date), to: Date
  defdelegate months_in_year(date), to: Date

  # Error helpers

  @doc false
  def unknown_calendar_error(calendar) do
    Localize.UnknownCalendarError.exception(calendar: calendar)
  end

  @doc false
  def unknown_territory_error(territory) do
    Localize.UnknownTerritoryError.exception(territory: territory)
  end

  # Calendar data delegation functions

  @doc """
  Returns the era data for a locale and calendar type.

  ### Arguments

  * `locale` is any locale returned by `Localize.known_locale_names/0`.
    The default is `Localize.get_locale/0`.

  * `calendar` is a calendar type atom. The default is `:gregorian`.

  ### Returns

  * A map of era data.

  """
  def eras(locale \\ Localize.get_locale(), calendar \\ :gregorian) do
    Localize.Calendar.eras(locale, calendar)
  end

  @doc """
  Returns the month name data for a locale and calendar type.

  ### Arguments

  * `locale` is any locale returned by `Localize.known_locale_names/0`.
    The default is `Localize.get_locale/0`.

  * `calendar` is a calendar type atom. The default is `:gregorian`.

  ### Returns

  * A map of month name data.

  """
  def months(locale \\ Localize.get_locale(), calendar \\ :gregorian) do
    Localize.Calendar.months(locale, calendar)
  end

  @doc """
  Returns the day name data for a locale and calendar type.

  ### Arguments

  * `locale` is any locale returned by `Localize.known_locale_names/0`.
    The default is `Localize.get_locale/0`.

  * `calendar` is a calendar type atom. The default is `:gregorian`.

  ### Returns

  * A map of day name data.

  """
  def days(locale \\ Localize.get_locale(), calendar \\ :gregorian) do
    Localize.Calendar.days(locale, calendar)
  end

  @doc """
  Returns the quarter name data for a locale and calendar type.

  ### Arguments

  * `locale` is any locale returned by `Localize.known_locale_names/0`.
    The default is `Localize.get_locale/0`.

  * `calendar` is a calendar type atom. The default is `:gregorian`.

  ### Returns

  * A map of quarter name data.

  """
  def quarters(locale \\ Localize.get_locale(), calendar \\ :gregorian) do
    Localize.Calendar.quarters(locale, calendar)
  end

  @doc """
  Returns the day period data for a locale and calendar type.

  ### Arguments

  * `locale` is any locale returned by `Localize.known_locale_names/0`.
    The default is `Localize.get_locale/0`.

  * `calendar` is a calendar type atom. The default is `:gregorian`.

  ### Returns

  * A map of day period data.

  """
  def day_periods(locale \\ Localize.get_locale(), calendar \\ :gregorian) do
    Localize.Calendar.day_periods(locale, calendar)
  end

  @doc """
  Returns the cyclic year data for a locale and calendar type.

  ### Arguments

  * `locale` is any locale returned by `Localize.known_locale_names/0`.
    The default is `Localize.get_locale/0`.

  * `calendar` is a calendar type atom. The default is `:gregorian`.

  ### Returns

  * A map of cyclic year data.

  """
  def cyclic_years(locale \\ Localize.get_locale(), calendar \\ :gregorian) do
    Localize.Calendar.cyclic_years(locale, calendar)
  end

  @doc """
  Returns the month pattern data for a locale and calendar type.

  ### Arguments

  * `locale` is any locale returned by `Localize.known_locale_names/0`.
    The default is `Localize.get_locale/0`.

  * `calendar` is a calendar type atom. The default is `:gregorian`.

  ### Returns

  * A map of month pattern data, or `nil` if no patterns exist.

  """
  def month_patterns(locale \\ Localize.get_locale(), calendar \\ :gregorian) do
    Localize.Calendar.month_patterns(locale, calendar)
  end

  # Functions that aid in pattern matching
  # in function heads

  @doc false
  def datetime do
    quote do
      %{
        year: _,
        month: _,
        day: _,
        hour: _,
        minute: _,
        second: _,
        microsecond: _,
        time_zone: _,
        zone_abbr: _,
        utc_offset: _,
        std_offset: _,
        calendar: var!(calendar)
      }
    end
  end

  @doc false
  def naivedatetime do
    quote do
      %{
        year: _,
        month: _,
        day: _,
        hour: _,
        minute: _,
        second: _,
        microsecond: _,
        calendar: var!(calendar)
      }
    end
  end

  @doc false
  def date do
    quote do
      %{
        year: _,
        month: _,
        day: _,
        calendar: var!(calendar)
      }
    end
  end

  @doc false
  def time do
    quote do
      %{
        hour: _,
        minute: _,
        second: _,
        microsecond: _
      }
    end
  end

  # Private helper to unwrap {:ok, data} tuples from Localize.Calendar functions.
  # Used internally when we need the raw data for get_in/2 access.
  @doc false
  defp unwrap!({:ok, data}), do: data
  defp unwrap!({:error, _}), do: nil
end
