defmodule Calendrical.Lunisolar do
  @moduledoc """
  Shared base implementation for Calendrical's lunisolar calendars.

  A lunisolar calendar approximates the tropical year using lunar months,
  inserting an intercalary (leap) month roughly every three years to keep the
  calendar aligned with the seasons. Calendrical implements three lunisolar
  calendars on top of this module:

  * `Calendrical.Chinese` — observation point Beijing.

  * `Calendrical.Korean` (Dangi) — observation point Seoul.

  * `Calendrical.LunarJapanese` — observation point Tokyo.

  Each implementation is a thin wrapper that supplies its epoch and an
  observation-location function (latitude, longitude, altitude, time-zone
  offset). All of the astronomical heavy lifting — winter solstice, mean and
  true new moon, leap-month detection, sexagesimal cycle calculations — is
  delegated to `Astro` and lives in this module.

  This module is **not** intended to be called directly from application code.
  Use one of the lunisolar calendar modules above and the standard `Date` and
  `Calendar` APIs.

  ## Naming conventions

  Several "year" and "month" concepts coexist in a lunisolar calendar. To keep
  the code unambiguous, this module uses the following names consistently:

  * `year` is the calendar year, counted as the number of years since the
    calendar's epoch.

  * `cyclical_year` is the position within the 60-year sexagesimal cycle
    (1..60).

  * `cycle` is the number of completed sexagesimal cycles since the epoch.

  * `month` is the *ordinal* month of the calendar year — 1..12 in an ordinary
    year and 1..13 in a leap year. This is the value the `Calendar` behaviour
    expects.

  * `lunar_month` is the *traditional* month number, 1..12 in all years, with
    leap months represented as `{month, :leap}`. This is the value users see
    in cultural contexts and the form returned by `Calendrical.localize/3`.

  ## References

  * Reingold and Dershowitz, *Calendrical Calculations: The Ultimate Edition*,
    4th ed., chapters on the Chinese, Korean and Japanese calendars.

  * The accompanying Common Lisp source distributed with the same book.

  """

  import Astro.Math,
    only: [
      mod: 2,
      amod: 2,
      deg: 1,
      next: 2
    ]

  alias Astro.{Lunar, Solar, Time}

  @typedoc "A lunar month"
  @type lunar_month :: Calendar.month() | {Calendar.month(), :leap}

  @typedoc "A sexigesimal cycle number"
  @type cycle :: pos_integer()

  # Winter season in degrees
  @winter 270

  # Number of years in a cycle
  @years_in_cycle 60

  # Calculating solar events in
  # the following year (in days)
  @one_solar_year_later 370

  # This is the number of months
  # in the calendar (not the number
  # of new moons) for a normal year.
  @lunar_calendar_months_in_year 12

  # A day in the middle of a lunar year. Lunar new year falls between
  # 21 January and 20 February, so the mean new year is 5 February and
  # the mean middle of the year six months later. Any whole number of
  # mean tropical years from here is also the middle of a lunar year.
  @mean_mid_lunar_year Calendar.ISO.date_to_iso_days(2000, 8, 6)

  # The 24 solar terms in index order, from `lichun` (index 1, 315°) every 15°
  # of solar ecliptic longitude — the order `solar_term/3` numbers them in.
  @solar_term_names {
    "lichun",
    "yushui",
    "jingzhe",
    "chunfen",
    "qingming",
    "guyu",
    "lixia",
    "xiaoman",
    "mangzhong",
    "xiazhi",
    "xiaoshu",
    "dashu",
    "liqiu",
    "chushu",
    "bailu",
    "qiufen",
    "hanlu",
    "shuangjiang",
    "lidong",
    "xiaoxue",
    "daxue",
    "dongzhi",
    "xiaohan",
    "dahan"
  }

  # The months are counted from the year's own number, which is the same
  # in Reingold's reckoning, so its month name epoch of 57 holds as it is:
  # the first month of a 癸 year, such as 4660 (2023), is 甲寅.
  @month_name_epoch 57

  # The Gregorian years whose days the new moon searches answer for: a few
  # beyond the 40,001 years a lunisolar calendar answers for (see
  # `Calendrical.Calendar.Lunisolar`), as the searches for a year at its edge
  # look a little past it. Far beyond them the series for a new moon's moment
  # drifts from its mean timing faster than a search can follow.
  @supported_gregorian_years -20_005..20_005
  @first_supported_day Calendar.ISO.date_to_iso_days(-20_005, 1, 1)
  @last_supported_day Calendar.ISO.date_to_iso_days(20_005, 12, 31)

  # Reingold's day name epoch is R.D. 45, 14 February 1 CE, counted from
  # R.D. 1, 1 January 1 CE. ISO days count from 1 January 0, 365 days
  # earlier, so the epoch is that day's ISO number: 1 October 1949 is then
  # 甲子, as it is recorded.
  @day_name_epoch Calendar.ISO.date_to_iso_days(1, 2, 14)

  @doc """
  Creates a date in the lunisolar calendar as an ISO day number.

  ### Arguments

  * `year` is a year of the lunisolar calendar.

  * `lunar_month` is a month of the year, as a positive integer or as
    `{month, :leap}` for the leap month.

  * `day` is a day of the month.

  * `epoch` is the ISO day number of the first day of the calendar's
    year 1, as a calendar's `epoch/0` returns it.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The ISO day number of the date.

  * `{:error, %Calendrical.InvalidDateError{}}` if the year has no such
    month or the month no such day.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.new(4660, 1, 1, epoch, location)
      738907

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.new(4660, 1, 31, epoch, location)
      {:error, %Calendrical.InvalidDateError{value: {4660, 1, 31}}}

  """

  def new(year, lunar_month, day, epoch, location_fun) do
    case traditional_date(year, lunar_month, day, epoch, location_fun) do
      {:ok, _month, start_of_month} -> start_of_month + day - 1
      {:error, _exception} = error -> error
    end
  end

  @doc false
  # The ordinal date `{year, month, day}` of a traditional date, as
  # `{:ok, date}`, or a `Calendrical.InvalidDateError` with no calendar,
  # which the engine is not told, when the year has no such month or the
  # month no such day.
  def ordinal_date(year, lunar_month, day, epoch, location_fun) do
    case traditional_date(year, lunar_month, day, epoch, location_fun) do
      {:ok, month, _start_of_month} -> {:ok, {year, month, day}}
      {:error, _exception} = error -> error
    end
  end

  # A traditional date's ordinal month and that month's first day, from the
  # year's new year and leap month found once.
  defp traditional_date(year, lunar_month, day, epoch, location_fun)
       when is_integer(year) and is_integer(day) and day >= 1 do
    {new_year, leap_month} = new_year_and_leap_month(year, epoch, location_fun)

    with {:ok, month} <- ordinal_month(year, lunar_month, day, leap_month),
         start_of_month = month_start(new_year, month, location_fun),
         days_in_month = month_start(new_year, month + 1, location_fun) - start_of_month,
         :ok <- day_in_month(year, lunar_month, day, days_in_month) do
      {:ok, month, start_of_month}
    end
  end

  defp traditional_date(year, lunar_month, day, _epoch, _location_fun),
    do: invalid_date(year, lunar_month, day)

  # A month the year does not have names no date.
  defp ordinal_month(year, lunar_month, day, leap_month) do
    case traditional_to_ordinal(lunar_month, leap_month) do
      {:ok, month} -> {:ok, month}
      {:error, _no_such_month} -> invalid_date(year, lunar_month, day)
    end
  end

  defp day_in_month(_year, _lunar_month, day, days_in_month) when day <= days_in_month, do: :ok

  defp day_in_month(year, lunar_month, day, _days_in_month),
    do: invalid_date(year, lunar_month, day)

  defp invalid_date(year, lunar_month, day),
    do: {:error, Calendrical.InvalidDateError.exception(value: {year, lunar_month, day})}

  # A leap month repeats the number of the month before it, so the months
  # from it on number one fewer than their ordinal: with a leap month at
  # ordinal 3 (`{2, :leap}`), traditional month 3 is ordinal 4. The lunar new
  # year is never a leap month, so a leap month's ordinal is at least 2.
  defp traditional_to_ordinal(lunar_month, leap_month)
       when lunar_month in 1..@lunar_calendar_months_in_year do
    if is_integer(leap_month) and leap_month <= lunar_month,
      do: {:ok, lunar_month + 1},
      else: {:ok, lunar_month}
  end

  defp traditional_to_ordinal({lunar_month, :leap}, leap_month)
       when lunar_month in 1..@lunar_calendar_months_in_year and leap_month == lunar_month + 1,
       do: {:ok, leap_month}

  defp traditional_to_ordinal(lunar_month, _leap_month),
    do: {:error, Calendrical.InvalidMonthError.exception(month: lunar_month)}

  @doc false
  # Adds years to an ordinal date keeping its traditional month: the
  # month's traditional number in `year` is found again in the new year,
  # where a leap month the new year lacks becomes the ordinary month of the
  # same number.
  def plus_years(year, month, day, years, options, epoch, location_fun) do
    new_year = year + years
    lunar_month = ordinal_to_traditional(month, leap_month(year, epoch, location_fun))
    new_month = constrained_ordinal(lunar_month, leap_month(new_year, epoch, location_fun))

    new_day =
      if Keyword.get(options, :clamp, false) do
        min(day, days_in_month(new_year, new_month, epoch, location_fun))
      else
        day
      end

    {new_year, new_month, new_day}
  end

  defp ordinal_to_traditional(month, leap_month)
       when is_integer(leap_month) and month == leap_month,
       do: {month - 1, :leap}

  defp ordinal_to_traditional(month, leap_month)
       when is_integer(leap_month) and month > leap_month,
       do: month - 1

  defp ordinal_to_traditional(month, _leap_month), do: month

  defp constrained_ordinal({lunar_month, :leap}, leap_month)
       when leap_month == lunar_month + 1,
       do: leap_month

  defp constrained_ordinal({lunar_month, :leap}, leap_month),
    do: constrained_ordinal(lunar_month, leap_month)

  defp constrained_ordinal(lunar_month, leap_month)
       when is_integer(leap_month) and leap_month <= lunar_month,
       do: lunar_month + 1

  defp constrained_ordinal(lunar_month, _leap_month), do: lunar_month

  @doc false
  # The months from one ordinal date's month to another's, counted by the new
  # moons that open them: every month begins on the day of a new moon, and a
  # true new moon falls within a day or two of the mean one, so the days
  # between two month starts divided by the mean synodic month, rounded, is
  # the count — one calculation, however many years apart the dates are.
  def months_between(
        {year_from, month_from, _day_from},
        {year_to, month_to, _day_to},
        epoch,
        location_fun
      ) do
    days =
      date_to_iso_days(year_to, month_to, 1, epoch, location_fun) -
        date_to_iso_days(year_from, month_from, 1, epoch, location_fun)

    round(days / Time.mean_synodic_month())
  end

  @doc """
  Returns the Gregorian date for the lunar month and day in a
  given Gregorian year.

  ### Arguments

  * `gregorian_year` is a Gregorian year.

  * `lunar_month` is a month of the lunar year that begins in that
    Gregorian year.

  * `lunar_day` is a day of that month.

  * `epoch` is the ISO day number of the first day of the calendar's
    year 1, as a calendar's `epoch/0` returns it.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * `{year, month, day}` in the Gregorian calendar.

  Raises `Calendrical.InvalidDateError` when the lunar year has no such
  month, or the month no such day.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.gregorian_date_for_lunar(2023, 1, 1, epoch, location)
      {2023, 1, 22}

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.gregorian_date_for_lunar(2024, {2, :leap}, 1, epoch, location)
      ** (Calendrical.InvalidDateError) [gregorian_year: 2024, lunar_month: {2, :leap}, lunar_day: 1] is not a date

  """
  def gregorian_date_for_lunar(gregorian_year, lunar_month, lunar_day, epoch, location_fun)
      when is_integer(gregorian_year) do
    mid_year = Calendar.ISO.date_to_iso_days(gregorian_year, 7, 1)

    {cycle, cyclic_year, _month, _day} =
      cyclical_date_from_iso_days(mid_year, epoch, location_fun)

    year = elapsed_years(cycle, cyclic_year)

    case traditional_date(year, lunar_month, lunar_day, epoch, location_fun) do
      {:ok, _month, start_of_month} ->
        Calendar.ISO.date_from_iso_days(start_of_month + lunar_day - 1)

      {:error, %Calendrical.InvalidDateError{}} ->
        raise Calendrical.InvalidDateError,
          calendar: nil,
          value: [gregorian_year: gregorian_year, lunar_month: lunar_month, lunar_day: lunar_day]
    end
  end

  # The sexagenary cycle runs with the lunar year, and 4 CE began one
  # (甲子), so a year's place in it follows from the Gregorian year its
  # lunar year begins in, whatever year a calendar counts from.
  @doc false
  @spec cyclic_year_from_related_gregorian_year(integer) :: cycle
  def cyclic_year_from_related_gregorian_year(related_gregorian_year)
      when is_integer(related_gregorian_year) do
    Integer.mod(related_gregorian_year - 4, @years_in_cycle) + 1
  end

  @doc false
  def lunar_month_of_year(year, month, day, epoch, location_fun) do
    iso_days = date_to_iso_days(year, month, day, epoch, location_fun)
    {month, _start_of_month, leap_month?} = month_and_leap(iso_days, location_fun)

    case {month, leap_month?} do
      {month, true} -> {month, :leap}
      {month, false} -> month
    end
  end

  @doc """
  Returns whether the given year is a leap year.

  Leap years have 13 months. To determine if a year
  is a leap year, calculate the number of new moons
  between the 11th month in one year (i.e., the month
  containing the Winter Solstice) and the 11th month
  in the following year.

  If there are 13 new moons from the start of the 11th
  month in the first year to the start of the 11th
  month in the second year, a leap month must be inserted.

  In leap years, at least one month does not contain a
  Principal Term. The first such month is the leap month.

  The additional complexity is that a leap year is
  calculated for the solar year, but the calendar
  is managed in lunar years and months. Therefore when
  a leap year is detected, the leap month could be in
  the current lunar year or the next lunar year.

  ### Arguments

  * `year` is a year of the lunisolar calendar.

  * `epoch` is the ISO day number of the first day of the calendar's
    year 1, as a calendar's `epoch/0` returns it.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * `true` if the year has 13 months, otherwise `false`.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.leap_year?(4660, epoch, location)
      true
      iex> Calendrical.Lunisolar.leap_year?(4661, epoch, location)
      false

  """

  def leap_year?(year, epoch, location_fun) do
    {{new_year, _leap}, _next_solstice, {next_new_year, _next_leap}} =
      year_suis(year, epoch, location_fun)

    thirteen_months?(new_year, next_new_year)
  end

  # A 13-month year spans 383..385 days and an ordinary year 353..355.
  # `round/1` maps both ranges correctly; `floor/1` would truncate a
  # 383-day leap year to 12 months (383 / 29.53 ≈ 12.97).
  defp thirteen_months?(new_year, next_new_year) do
    round((next_new_year - new_year) / Time.mean_synodic_month()) == 13
  end

  @doc """
  Returns whether the given month of a year is its leap month.

  Approximately every three years (7 times in 19 years),
  a leap month is added to the Chinese calendar.

  To determine when, find the number of new moons between
  the 11th month in one year and the 11th month in the
  following year.

  A leap month is inserted if there are 13 New Moons
  from the start of the 11th month in the first year
  to the start of the 11th month in the next year.

  The Chinese calendar uses a solar term system
  that has 12 principal terms to indicate when the Sun's
  longitude is a multiple of 30 degrees.

  Unlike all other months, the leap month does not
  contain a principal term (Zhongqi).

  ### Arguments

  * `year` is a year of the lunisolar calendar.

  * `month` is an ordinal month of the year, counting the leap month.

  * `epoch` is the ISO day number of the first day of the calendar's
    year 1, as a calendar's `epoch/0` returns it.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * `true` if `month` is the year's leap month, otherwise `false`.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.leap_month?(4660, 3, epoch, location)
      true
      iex> Calendrical.Lunisolar.leap_month?(4660, 4, epoch, location)
      false

  """
  def leap_month?(year, month, epoch, location_fun) do
    leap_month(year, epoch, location_fun) == month
  end

  @doc """
  Returns whether `month` is the leap month of the year given as a
  cycle and the year within the cycle.

  ### Arguments

  * `cycle` is the 60-year cycle.

  * `cyclical_year` is the year within the cycle, from `1` to `60`.

  * `month` is the ordinal month of the year.

  * `epoch` is the calendar's epoch in ISO days.

  * `location_fun` is a function that takes a moment and returns the
    `{latitude, longitude, altitude, offset}` of the calendar's
    reference location.

  ### Returns

  * `true` if `month` is the year's leap month, otherwise `false`.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.leap_month?(78, 40, 3, epoch, location)
      true

  """
  def leap_month?(cycle, cyclical_year, month, epoch, location_fun) do
    cycle
    |> elapsed_years(cyclical_year)
    |> leap_month?(month, epoch, location_fun)
  end

  @doc """
  Returns the ordinal number of a year's leap month.

  ### Arguments

  * `year` is a year of the lunisolar calendar.

  * `epoch` is the ISO day number of the first day of the calendar's
    year 1, as a calendar's `epoch/0` returns it.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The ordinal month that is the leap month, counting it among the
    year's months, or `nil` if the year has none.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.leap_month(4660, epoch, location)
      3
      iex> Calendrical.Lunisolar.leap_month(4661, epoch, location)
      nil

  """
  def leap_month(year, epoch, location_fun) do
    {_new_year, leap_month} = new_year_and_leap_month(year, epoch, location_fun)
    leap_month
  end

  # The new year that begins `year` and the ordinal of its leap month, `nil`
  # when the year has 12 months.
  defp new_year_and_leap_month(year, epoch, location_fun) do
    {{new_year, leap}, next_solstice, {next_new_year, next_leap}} =
      year_suis(year, epoch, location_fun)

    if thirteen_months?(new_year, next_new_year) do
      # Month 1 is never the leap month, so the search starts at month 2.
      second_month = new_moon_on_or_after(new_year + 1, location_fun)
      term = current_major_solar_term(second_month, location_fun)
      suis = {next_solstice, leap, next_leap}
      {new_year, first_leap_month(2, second_month, term, suis, location_fun)}
    else
      {new_year, nil}
    end
  end

  # The leap month is the first month of a leap sui, counted from its month
  # 12, without a major solar term of its own. A month belongs to the sui of
  # the December solstice on or before its first day. The year's months in
  # its first sui hold that sui's leap month only when it did not come before
  # the new year; the rest of the year starts the next sui, whose first
  # term-less month is its leap month.
  defp first_leap_month(month, _start, _term, _suis, _location_fun)
       when month > @lunar_calendar_months_in_year + 1 do
    nil
  end

  defp first_leap_month(month, start, term, suis, location_fun) do
    {next_solstice, leap, next_leap} = suis
    next_start = new_moon_on_or_after(start + 1, location_fun)
    next_term = current_major_solar_term(next_start, location_fun)

    if leap_month_possible?(start, next_solstice, leap, next_leap) and term == next_term do
      month
    else
      first_leap_month(month + 1, next_start, next_term, suis, location_fun)
    end
  end

  defp leap_month_possible?(start, next_solstice, leap, _next_leap) when start < next_solstice,
    do: leap == :after_new_year

  defp leap_month_possible?(_start, _next_solstice, _leap, next_leap), do: next_leap != :none

  # This makes clear how simple the calendar is - just a sequence of
  # months aligned to new moons. The complication is only determining
  # the start of the year and leap months.

  @doc """
  Returns the ISO day number of a lunisolar date whose months are
  ordinal: numbered 1 to 12, or 1 to 13 in a leap year, with the
  leap month unmarked.

  ### Arguments

  * `year` is the year counted from the calendar's epoch.

  * `month` is the ordinal month of the year.

  * `day` is the day of the month.

  * `epoch` is the calendar's epoch in ISO days.

  * `location_fun` is a function that takes a moment and returns the
    `{latitude, longitude, altitude, offset}` of the calendar's
    reference location.

  ### Returns

  * The number of days since the ISO epoch, as an integer.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.date_to_iso_days(4660, 1, 1, epoch, location)
      738907

  """
  @spec date_to_iso_days(
          integer,
          integer,
          integer,
          integer,
          (Time.time() -> {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()})
        ) :: integer
  def date_to_iso_days(year, month, day, epoch, location_fun)
      when is_integer(year) and is_integer(month) and is_integer(day) and is_integer(epoch) do
    {cycle, cyclic_year} = cycle_and_year(year)
    cyclical_date_to_iso_days(cycle, cyclic_year, month, day, epoch, location_fun)
  end

  # defp date_to_iso_days({year, month, day}, epoch, location_fun) do
  #   date_to_iso_days(year, month, day, epoch, location_fun)
  # end

  @doc """
  Returns the ISO day number of a lunisolar date whose year is given
  as a cycle and the year within the cycle, and whose months are
  ordinal.

  ### Arguments

  * `cycle` is the 60-year cycle.

  * `cyclical_year` is the year within the cycle, from `1` to `60`.

  * `month` is the ordinal month of the year.

  * `day` is the day of the month.

  * `epoch` is the calendar's epoch in ISO days.

  * `location_fun` is a function that takes a moment and returns the
    `{latitude, longitude, altitude, offset}` of the calendar's
    reference location.

  ### Returns

  * The number of days since the ISO epoch, as an integer.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.cyclical_date_to_iso_days(78, 40, 1, 1, epoch, location)
      738907

  """
  @spec cyclical_date_to_iso_days(
          integer,
          integer,
          integer,
          integer,
          integer,
          (Time.time() -> {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()})
        ) :: integer
  def cyclical_date_to_iso_days(cycle, cyclical_year, month, day, epoch, location_fun)
      when is_integer(cycle) and is_integer(cyclical_year) and is_integer(month) and
             is_integer(day) and is_integer(epoch) do
    new_year =
      cycle
      |> mid_year(cyclical_year, epoch)
      |> new_year_on_or_before(location_fun)

    month_start(new_year, month, location_fun) + day - 1
  end

  # The first day of ordinal month `month` in the year that begins on
  # `new_year`: the new year itself for month 1, otherwise the first new moon
  # on or after 29 days a month later, which is always inside that month.
  defp month_start(new_year, 1, _location_fun), do: new_year

  defp month_start(new_year, month, location_fun) do
    new_moon_on_or_after(new_year + (month - 1) * 29, location_fun)
  end

  # The new year that begins `year`.
  defp new_year(year, epoch, location_fun) do
    {cycle, cyclical_year} = cycle_and_year(year)

    cycle
    |> mid_year(cyclical_year, epoch)
    |> new_year_on_or_before(location_fun)
  end

  # The two suis that `year` spans: the one its new year falls in and the one
  # the next year's new year falls in, as `{new_year, leap}` each (see `sui/3`), with
  # the December solstice between them. The three solstices are found once
  # and shared by both suis.
  defp year_suis(year, epoch, location_fun) do
    {cycle, cyclical_year} = cycle_and_year(year)

    solstice =
      cycle
      |> mid_year(cyclical_year, epoch)
      |> december_solstice_on_or_before(location_fun)

    next_solstice = next_december_solstice(solstice, location_fun)
    following_solstice = next_december_solstice(next_solstice, location_fun)

    {sui(solstice, next_solstice, location_fun), next_solstice,
     sui(next_solstice, following_solstice, location_fun)}
  end

  # defp cyclical_date_to_iso_days({cycle, cyclical_year, month, day}, epoch, location_fun) do
  #   cyclical_date_to_iso_days(cycle, cyclical_year, month, day, epoch, location_fun)
  # end

  @doc """
  Returns the lunisolar date of an ISO day number, with ordinal
  months that run from 1 to 12, or 1 to 13 in a leap year.

  ### Arguments

  * `iso_days` is the number of days since the ISO epoch.

  * `epoch` is the calendar's epoch in ISO days.

  * `location_fun` is a function that takes a moment and returns the
    `{latitude, longitude, altitude, offset}` of the calendar's
    reference location.

  ### Returns

  * A `{year, month, day}` tuple, the year counted from the
    calendar's epoch.

  ### Examples

      iex> epoch = Calendrical.Chinese.epoch()
      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.date_from_iso_days(738907, epoch, location)
      {4660, 1, 1}

  """
  def date_from_iso_days(iso_days, epoch, location_fun) do
    {cycle, cyclical_year, month, day} =
      cyclical_date_from_iso_days(iso_days, epoch, location_fun)

    elapsed_years = elapsed_years(cycle, cyclical_year)

    {elapsed_years, month, day}
  end

  # THis version returns the cyclical year and ordinal month
  @doc false
  def cyclical_date_from_iso_days(iso_days, epoch, location_fun) do
    new_year = new_year_on_or_before(iso_days, location_fun)
    start_of_month = new_moon_before(iso_days + 1, location_fun)
    elapsed_years = year_beginning_on(new_year, epoch)

    month =
      ((start_of_month - new_year) / Time.mean_synodic_month() + 1)
      |> round()

    day =
      (iso_days - start_of_month + 1)
      |> round()

    {cycle, cyclic_year} = cycle_and_year(elapsed_years)
    {cycle, cyclic_year, month, day}
  end

  # This version returns the cyclical year and *lunar* month with leap
  # month indicator.
  @doc false
  def alt_cyclical_date_from_iso_days(iso_days, epoch, location_fun) do
    {lunar_month, start_of_month, leap_month?} = month_and_leap(iso_days, location_fun)

    elapsed_years = floor(1.5 - lunar_month / 12 + (iso_days - epoch) / Time.mean_tropical_year())
    {cycle, cyclic_year} = cycle_and_year(elapsed_years)

    day = iso_days - start_of_month + 1

    {cycle, cyclic_year, lunar_month, leap_month?, day}
  end

  @doc false
  @spec elapsed_years(integer(), integer()) :: integer()
  def elapsed_years(cycle, cyclic_year) when is_integer(cycle) and is_integer(cyclic_year) do
    (cycle - 1) * @years_in_cycle + cyclic_year
  end

  @doc false
  def elapsed_years({cycle, cyclic_year}) do
    elapsed_years(cycle, cyclic_year)
  end

  @doc false
  @spec cycle_and_year(integer) :: {integer, integer}
  def cycle_and_year(elapsed_years) when is_integer(elapsed_years) do
    cycle = 1 + floor((elapsed_years - 1) / @years_in_cycle)
    cyclic_year = amod(elapsed_years, @years_in_cycle)

    {cycle, cyclic_year}
  end

  @doc false
  # The length of ordinal month `month`: from its first day to the first day
  # of the month after it. The month after the year's last month is the next
  # year's first, so one new year answers every month.
  def days_in_month(year, month, epoch, location_fun) do
    new_year = new_year(year, epoch, location_fun)
    month_start(new_year, month + 1, location_fun) - month_start(new_year, month, location_fun)
  end

  @doc false
  # The number of days from the new year of `year` to the next.
  def days_in_year(year, epoch, location_fun) do
    {{new_year, _leap}, _next_solstice, {next_new_year, _next_leap}} =
      year_suis(year, epoch, location_fun)

    next_new_year - new_year
  end

  @doc false
  # The `Calendar.valid_date?/3` answer for an ordinal date: the month is in
  # the year and the day in the month. Months 1..12 are in every year, so only
  # month 13 needs the next new year.
  def valid_date?(year, 13, day, epoch, location_fun)
      when is_integer(year) and is_integer(day) and day >= 1 do
    {{new_year, _leap}, _next_solstice, {next_new_year, _next_leap}} =
      year_suis(year, epoch, location_fun)

    thirteen_months?(new_year, next_new_year) and
      day <= next_new_year - month_start(new_year, 13, location_fun)
  end

  def valid_date?(year, month, day, epoch, location_fun)
      when is_integer(year) and month in 1..@lunar_calendar_months_in_year and is_integer(day) and
             day >= 1 do
    day <= days_in_month(year, month, epoch, location_fun)
  end

  def valid_date?(_year, _month, _day, _epoch, _location_fun), do: false

  defp leap_lunisolar_year?({start_of_year, end_of_year}) do
    leap_lunisolar_year?(start_of_year, end_of_year)
  end

  defp leap_lunisolar_year?(iso_days, location_fun)
       when is_number(iso_days) and is_function(location_fun) do
    iso_days
    |> lunisolar_year(location_fun)
    |> leap_lunisolar_year?()
  end

  defp leap_lunisolar_year?(start_of_year, end_of_year) do
    # 12 full lunar months means 13 new moons
    round((end_of_year - start_of_year) / Time.mean_synodic_month()) ==
      @lunar_calendar_months_in_year
  end

  @doc false
  def leap_lunisolar_year?(year, month, day, epoch, location_fun) do
    iso_days = date_to_iso_days(year, month, day, epoch, location_fun)
    leap_lunisolar_year?(iso_days, location_fun)
  end

  # Original version in which the month number doesn't change for
  # a leap month (but the leap_month? flag is set for the second
  # month with the same number)

  @doc false
  defmacrop leap_month?(d) do
    quote do
      elem(unquote(d), 3)
    end
  end

  @doc false
  defmacrop month(d) do
    quote do
      elem(unquote(d), 2)
    end
  end

  @doc false
  def alt_cyclical_date_to_iso_days(
        cycle,
        cyclical_year,
        lunar_month,
        lunar_day,
        epoch,
        location_fun
      )
      when is_integer(lunar_month) do
    alt_cyclical_date_to_iso_days(
      cycle,
      cyclical_year,
      lunar_month,
      false,
      lunar_day,
      epoch,
      location_fun
    )
  end

  def alt_cyclical_date_to_iso_days(
        cycle,
        cyclical_year,
        {lunar_month, :leap},
        lunar_day,
        epoch,
        location_fun
      )
      when is_integer(lunar_month) do
    alt_cyclical_date_to_iso_days(
      cycle,
      cyclical_year,
      lunar_month,
      true,
      lunar_day,
      epoch,
      location_fun
    )
  end

  defp alt_cyclical_date_to_iso_days(
         cycle,
         cyclical_year,
         lunar_month,
         leap_month?,
         lunar_day,
         epoch,
         location_fun
       ) do
    mid_year = mid_year(cycle, cyclical_year, epoch)
    new_year = new_year_on_or_before(mid_year, location_fun)

    p = month_start(new_year, lunar_month, location_fun)
    d = alt_cyclical_date_from_iso_days(p, epoch, location_fun)

    prior_new_moon =
      if lunar_month == month(d) && leap_month? == leap_month?(d) do
        p
      else
        new_moon_on_or_after(1 + p, location_fun)
      end

    prior_new_moon + lunar_day - 1
  end

  @doc false
  # defp alt_cyclical_date_to_iso_days({cycle, cyclical_year, month, leap_month?, day}, epoch, location_fun) do
  #   alt_cyclical_date_to_iso_days(cycle, cyclical_year, month, leap_month?, day, epoch, location_fun)
  # end

  defp month_and_leap(iso_days, location_fun) do
    {prior_month_12, next_month_11} =
      lunisolar_year(iso_days, location_fun)

    leap_sui_year? =
      leap_lunisolar_year?(prior_month_12, next_month_11)

    start_of_month_in_iso_days =
      new_moon_before(iso_days + 1, location_fun)

    {prior_leap_month?, leap_month?} =
      leap_months_to(leap_sui_year?, prior_month_12, start_of_month_in_iso_days, location_fun)

    months = lunar_months_between(start_of_month_in_iso_days, prior_month_12)

    lunar_month =
      if(prior_leap_month?, do: months - 1, else: months)
      |> amod(@lunar_calendar_months_in_year)
      |> trunc()

    {lunar_month, start_of_month_in_iso_days, leap_month?}
  end

  # For the month starting on `start_of_month` in a sui whose month 12 starts
  # on `month_12`: whether a month from month 12 up to and including it has
  # no major solar term (a leap month has already occurred), and whether it
  # is itself the leap month — the sui's first month without one. Only a leap
  # sui has a leap month. The months are walked forward from month 12 once,
  # each month's term found once.
  defp leap_months_to(false = _leap_sui?, _month_12, _start_of_month, _location_fun),
    do: {false, false}

  defp leap_months_to(true = _leap_sui?, month_12, start_of_month, location_fun)
       when start_of_month < month_12 do
    {false, no_major_solar_term?(start_of_month, location_fun)}
  end

  defp leap_months_to(true = _leap_sui?, month_12, start_of_month, location_fun) do
    term = current_major_solar_term(month_12, location_fun)
    walk_leap_months(month_12, term, start_of_month, false, location_fun)
  end

  defp walk_leap_months(month_start, term, start_of_month, earlier_leap?, location_fun) do
    next_start = new_moon_on_or_after(month_start + 1, location_fun)
    next_term = current_major_solar_term(next_start, location_fun)
    no_major_term? = term == next_term

    if month_start >= start_of_month do
      {earlier_leap? or no_major_term?, no_major_term? and not earlier_leap?}
    else
      earlier_leap? = earlier_leap? or no_major_term?
      walk_leap_months(next_start, next_term, start_of_month, earlier_leap?, location_fun)
    end
  end

  defp lunisolar_year(iso_days, location_fun) do
    prior_solstice = december_solstice_on_or_before(iso_days, location_fun)
    prior_month_12 = new_moon_on_or_after(1 + prior_solstice, location_fun)

    next_solstice =
      december_solstice_on_or_before(prior_solstice + @one_solar_year_later, location_fun)

    next_month_11 = new_moon_before(1 + next_solstice, location_fun)

    {prior_month_12, next_month_11}
  end

  defp lunar_months_between(from_iso_days, to_iso_days) do
    round((from_iso_days - to_iso_days) / Time.mean_synodic_month())
  end

  # A day in the middle of the lunar year `cycle`/`cyclic_year`, from which
  # `new_year_on_or_before/2` finds that year's new year in a single pass.
  #
  # Half a year after the epoch's anniversary is mid-year only when the
  # epoch is itself a new year. For an epoch mid-year (a configured
  # `:lunar_japanese_epoch` such as 645-07-20) it lands between the
  # December solstice and the new year, so every lookup computed two sui
  # instead of one, and for an epoch in late July or August it duplicated
  # or skipped years.
  # Snapping to the nearest mean mid-lunar-year keeps the year the
  # estimate points into while staying months clear of either new year.
  # The year that begins on `new_year`, as `mid_year/3` places years: the
  # one whose mean middle is the first of its points on or after the new
  # year. Counting mean years from the epoch instead puts every year of a
  # calendar whose epoch is not its first new year near a half (the
  # lunisolar Japanese calendar's epoch, 20 July 645, is 165 days after its
  # year 1 began), and the drift of new years from the mean over millennia
  # then tips a year into the one before.
  defp year_beginning_on(new_year, epoch) do
    year = Time.mean_tropical_year()
    first_year_point = round((epoch - @mean_mid_lunar_year) / year + 1 / 2)
    ceil((new_year - @mean_mid_lunar_year) / year) - first_year_point + 1
  end

  defp mid_year(cycle, cyclic_year, epoch) do
    estimate =
      epoch +
        ((cycle - 1) * @years_in_cycle + (cyclic_year - 1) + 1 / 2) * Time.mean_tropical_year()

    years_from_reference = round((estimate - @mean_mid_lunar_year) / Time.mean_tropical_year())
    floor(@mean_mid_lunar_year + years_from_reference * Time.mean_tropical_year())
  end

  @doc """
  Return moment at `location` of the first date on or after
  `iso_days` when the solar longitude
  will be `lambda` degrees.

  ### Arguments

  * `lambda` is the solar longitude in degrees.

  * `iso_days` is the moment, in days since the ISO epoch, from which
    to search.

  * `location_fun` is a function that takes a moment and returns the
    `{latitude, longitude, altitude, offset}` of the calendar's
    reference location.

  ### Returns

  * The moment, in days since the ISO epoch at the location's standard
    time, when the sun reaches `lambda` degrees.

  ### Examples

      # 大寒 (sun at 300 degrees) falls on 2026-01-20 Beijing time
      iex> iso_days = Calendar.ISO.date_to_iso_days(2026, 1, 1)
      iex> location = &Calendrical.Chinese.location/1
      iex> moment = Calendrical.Lunisolar.solar_longitude_on_or_after(300, iso_days, location)
      iex> Calendar.ISO.date_from_iso_days(floor(moment))
      {2026, 1, 20}

  """
  @spec solar_longitude_on_or_after(
          Astro.angle(),
          number(),
          (Time.time() -> {Astro.angle(), Astro.angle(), Astro.meters(), Time.hours()})
        ) :: Time.time()

  def solar_longitude_on_or_after(lambda, iso_days, location_fun) do
    {_lat, _lng, _alt, offset} = location_fun.(iso_days)
    d = Time.universal_from_standard(iso_days, offset)
    t = Solar.solar_ecliptic_longitude_after(lambda, d)

    # The location function returns a {lat, lng, alt, offset} tuple;
    # standard_from_universal takes just the offset. Passing the whole
    # tuple raised FunctionClauseError on every call.
    {_lat, _lng, _alt, offset_at_t} = location_fun.(t)
    Time.standard_from_universal(t, offset_at_t)
  end

  @doc """
  The proleptic-Gregorian date on which the sun reaches the `index`-th solar
  term (jié-qì) during Gregorian `year`, observed at `location_fun`.

  The 24 solar terms are numbered from `lichun` (立春, index 1) at 315° solar
  ecliptic longitude, then every 15° (`qingming` = 5 at 15°, `dongzhi` = 22 at
  270°, …). The day is taken in the observer's local standard time, so the
  meridian — supplied by the calendar's `location/1` — decides the civil date.

  ### Arguments

  * `index` is the 1-based solar-term number, `1..24`.

  * `year` is a proleptic-Gregorian year.

  * `location_fun` is the observer's location function, taken from the lunisolar
    calendar (e.g. `&Calendrical.Chinese.location/1`).

  ### Returns

  * `{:ok, t:Date.t/0}` in `Calendrical.Gregorian`.

  * `{:error, %Calendrical.InvalidSolarTermError{}}` when `index` is not
    in `1..24`.

  ### Examples

      iex> Calendrical.Lunisolar.solar_term(5, 2025, &Calendrical.Chinese.location/1)
      {:ok, ~D[2025-04-04 Calendrical.Gregorian]}

  """
  def solar_term(index, gregorian_year, location_fun) when index in 1..24 do
    longitude = rem(300 + index * 15, 360)
    start = Calendrical.Gregorian.date_to_iso_days(gregorian_year, 1, 1)
    moment = solar_longitude_on_or_after(longitude, start, location_fun)
    {year, month, day} = Calendrical.Gregorian.date_from_iso_days(floor(moment))
    {:ok, %Date{year: year, month: month, day: day, calendar: Calendrical.Gregorian}}
  end

  def solar_term(index, _gregorian_year, _location_fun) do
    {:error, Calendrical.InvalidSolarTermError.exception(index: index)}
  end

  @doc """
  The name of the solar term (jié-qì) at a 1-based index.

  The 24 solar terms are numbered from `lichun` (立春, index 1) at 315° solar
  ecliptic longitude, then every 15° — the same order `solar_term/3` computes a
  term's date for, so an index that dates a term also names it.

  ### Arguments

  * `index` is the 1-based solar-term number, `1..24`.

  ### Returns

  * `{:ok, name}` with the term's romanised (pinyin) name, such as `"qingming"`.

  * `{:error, %Calendrical.InvalidSolarTermError{}}` when `index` is not
    in `1..24`.

  ### Examples

      iex> Calendrical.Lunisolar.solar_term_name(1)
      {:ok, "lichun"}

      iex> Calendrical.Lunisolar.solar_term_name(5)
      {:ok, "qingming"}

      iex> Calendrical.Lunisolar.solar_term_name(22)
      {:ok, "dongzhi"}

      iex> Calendrical.Lunisolar.solar_term_name(0)
      {:error, %Calendrical.InvalidSolarTermError{index: 0}}

  """
  @spec solar_term_name(integer()) ::
          {:ok, String.t()} | {:error, Exception.t()}
  def solar_term_name(index) when is_integer(index) and index in 1..24 do
    {:ok, elem(@solar_term_names, index - 1)}
  end

  def solar_term_name(index) do
    {:error, Calendrical.InvalidSolarTermError.exception(index: index)}
  end

  @doc """
  Returns the last Chinese major solar term (zhongqi) before
  `iso_days`.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The major solar term, 1 to 12.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.current_major_solar_term(739_038, location)
      4

  """
  def current_major_solar_term(iso_days, location_fun) do
    {_lat, _lng, _alt, offset} = location_fun.(iso_days)
    d = Time.universal_from_standard(iso_days, offset)
    s = Solar.solar_ecliptic_longitude(d)
    amod(2 + floor(trunc(s) / deg(30)), 12)
  end

  @doc """
  Returns the moment of the first major solar term (zhongqi) on or
  after `iso_days`. The major terms begin when the sun's longitude is
  a multiple of 30 degrees.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The moment, in fractional ISO days.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.major_solar_term_on_or_after(739_038, location) |> floor()
      739057

  """
  def major_solar_term_on_or_after(iso_days, location_fun) do
    s = Solar.solar_ecliptic_longitude(midnight_in_location(iso_days, location_fun))
    l = mod(30 * ceil(s / 30), 360)
    solar_longitude_on_or_after(l, iso_days, location_fun)
  end

  @doc """
  Returns the last minor solar term (jieqi) before `iso_days`.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The minor solar term, 1 to 12.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.current_minor_solar_term(739_038, location)
      4

  """
  def current_minor_solar_term(iso_days, location_fun) do
    {_lat, _lng, _alt, offset} = location_fun.(iso_days)
    d = Time.universal_from_standard(iso_days, offset)
    s = Solar.solar_ecliptic_longitude(d)
    # Parenthesized per Reingold & Dershowitz: floor((s - 15) / 30).
    # The unparenthesized form computed floor(s - 0.5).
    amod(3 + floor((s - deg(15)) / deg(30)), 12)
  end

  @doc """
  Returns the moment of the first minor solar term (jieqi) on or
  after `iso_days`. The minor terms begin when the sun's longitude is
  an odd multiple of 15 degrees.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The moment, in fractional ISO days.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.minor_solar_term_on_or_after(739_038, location) |> floor()
      739042

  """
  def minor_solar_term_on_or_after(iso_days, location_fun) do
    s = Solar.solar_ecliptic_longitude(midnight_in_location(iso_days, location_fun))
    l = mod(30 * ceil((s - deg(15)) / 30) + deg(15), 360)

    solar_longitude_on_or_after(l, iso_days, location_fun)
  end

  @doc """
  Returns the day of the first new moon before `iso_days`, at the
  calendar's place.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The ISO day number of the new moon.

  Raises `Calendrical.UnsupportedDateRangeError` for a day outside
  Gregorian years -20,005 to 20,005.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.new_moon_before(739_038, location)
      739024

  """
  def new_moon_before(iso_days, _location_fun)
      when iso_days < @first_supported_day or iso_days > @last_supported_day,
      do: raise(out_of_range(iso_days))

  def new_moon_before(iso_days, location_fun) do
    new_moon =
      iso_days
      |> midnight_in_location(location_fun)
      |> Lunar.date_time_new_moon_before()

    {_lat, _lng, _alt, offset} = location_fun.(new_moon)

    Time.standard_from_universal(new_moon, offset) |> floor()
  end

  @doc """
  Returns the day of the first new moon on or after `iso_days`, at
  the calendar's place.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The ISO day number of the new moon.

  Raises `Calendrical.UnsupportedDateRangeError` for a day outside
  Gregorian years -20,005 to 20,005.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.new_moon_on_or_after(739_038, location)
      739054

  """
  def new_moon_on_or_after(iso_days, _location_fun)
      when iso_days < @first_supported_day or iso_days > @last_supported_day,
      do: raise(out_of_range(iso_days))

  def new_moon_on_or_after(iso_days, location_fun) do
    new_moon =
      iso_days
      |> midnight_in_location(location_fun)
      |> Lunar.date_time_new_moon_at_or_after()

    {_lat, _lng, _alt, offset} = location_fun.(new_moon)

    Time.standard_from_universal(new_moon, offset) |> floor()
  end

  defp out_of_range(iso_days) do
    Calendrical.UnsupportedDateRangeError.exception(
      value: Date.from_gregorian_days(floor(iso_days)),
      range: @supported_gregorian_years
    )
  end

  @doc """
  Returns whether the lunar month starting on `iso_days` has no
  major solar term, as only a leap month has none.

  ### Arguments

  * `iso_days` is the ISO day number of the first day of a lunar month.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * `true` if the month has no major solar term, otherwise `false`.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.no_major_solar_term?(Date.to_gregorian_days(~D[2023-03-22]), location)
      true
      iex> Calendrical.Lunisolar.no_major_solar_term?(Date.to_gregorian_days(~D[2023-04-20]), location)
      false

  """
  def no_major_solar_term?(iso_days, location_fun) do
    new_moon = new_moon_on_or_after(iso_days + 1, location_fun)

    current_major_solar_term(iso_days, location_fun) ==
      current_major_solar_term(new_moon, location_fun)
  end

  @doc """
  Returns the universal time of the (clock) midnight that begins
  `iso_days` at the calendar's place.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The moment, in fractional ISO days.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.midnight_in_location(738_907, location)
      738906.6666666666

  """
  def midnight_in_location(iso_days, location_fun) do
    {_lat, _lng, _alt, offset} = location_fun.(iso_days)
    Time.universal_from_standard(iso_days, offset)
  end

  @doc """
  Returns the day of the winter solstice on or before `iso_days`, at
  the calendar's place.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The ISO day number of the solstice.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.december_solstice_on_or_before(739_038, location)
      738876

  """
  def december_solstice_on_or_before(iso_days, location_fun) do
    approx =
      Solar.estimate_prior_solar_ecliptic_longitude(
        @winter,
        midnight_in_location(iso_days + 1, location_fun)
      )

    next(
      floor(approx) - 1,
      &(@winter < Solar.solar_ecliptic_longitude(midnight_in_location(1 + &1, location_fun)))
    )
  end

  @doc """
  Returns the day of the Lunar New Year in the sui (the period from
  one winter solstice to the next) that contains `iso_days`.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The ISO day number of the new year.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.new_year_in_sui(739_038, location)
      738907

  """
  def new_year_in_sui(iso_days, location_fun) do
    solstice = december_solstice_on_or_before(iso_days, location_fun)

    {new_year, _leap} =
      sui(solstice, next_december_solstice(solstice, location_fun), location_fun)

    new_year
  end

  @doc """
  Returns the day of the Lunar New Year on or before `iso_days`, at
  the calendar's place.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The ISO day number of the new year.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.new_year_on_or_before(739_038, location)
      738907

  """
  def new_year_on_or_before(iso_days, location_fun) do
    solstice = december_solstice_on_or_before(iso_days, location_fun)

    {new_year, _leap} =
      sui(solstice, next_december_solstice(solstice, location_fun), location_fun)

    if iso_days >= new_year do
      new_year
    else
      # `iso_days` lies between the solstice and the new year after it, so its
      # new year is that of the previous sui, which ends at this solstice.
      previous_solstice = december_solstice_on_or_before(iso_days - 180, location_fun)
      {previous_new_year, _leap} = sui(previous_solstice, solstice, location_fun)
      previous_new_year
    end
  end

  # The December solstice a year after `solstice`.
  defp next_december_solstice(solstice, location_fun) do
    december_solstice_on_or_before(solstice + @one_solar_year_later, location_fun)
  end

  # The sui from the December solstice `solstice` to `next_solstice`, as
  # `{new_year, leap}`: its new year, and where its leap month falls —
  # `:none` in an ordinary sui, otherwise `:before_new_year` or
  # `:after_new_year`. Month 12 begins with the first new moon after the
  # solstice and the new year usually with the next (month 13 of the old
  # count). In a leap sui — 13 new moons from month 12 to the next month 11 —
  # the new year moves one month later when month 12 or the month after it
  # has no major solar term, since that month is the sui's leap month.
  defp sui(solstice, next_solstice, location_fun) do
    month_12 = new_moon_on_or_after(1 + solstice, location_fun)
    next_month_11 = new_moon_before(1 + next_solstice, location_fun)
    month_13 = new_moon_on_or_after(1 + month_12, location_fun)

    if leap_lunisolar_year?(month_12, next_month_11) do
      leap_sui_new_year(month_12, month_13, location_fun)
    else
      {month_13, :none}
    end
  end

  defp leap_sui_new_year(month_12, month_13, location_fun) do
    month_14 = new_moon_on_or_after(1 + month_13, location_fun)
    term_12 = current_major_solar_term(month_12, location_fun)
    term_13 = current_major_solar_term(month_13, location_fun)

    if term_12 == term_13 or term_13 == current_major_solar_term(month_14, location_fun) do
      {month_14, :before_new_year}
    else
      {month_13, :after_new_year}
    end
  end

  @doc """
  Returns the day of the Lunar New Year in a Gregorian year, at the
  calendar's place.

  ### Arguments

  * `gregorian_year` is a Gregorian year.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * The ISO day number of the new year.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> Calendrical.Lunisolar.chinese_new_year_for_gregorian_year(2023, location)
      738907

  """
  def chinese_new_year_for_gregorian_year(gregorian_year, location_fun) do
    iso_days = Calendrical.Gregorian.date_to_iso_days(gregorian_year, 7, 1)
    new_year_on_or_before(iso_days, location_fun)
  end

  @doc """
  Returns whether there is a leap month from the lunar month starting
  on `m_prime` up to and including the lunar month starting on `m`.

  ### Arguments

  * `m_prime` is the ISO day number of the first day of the earlier
    lunar month.

  * `m` is the ISO day number of the first day of the later lunar
    month.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, the place the
    calendar is reckoned at, as a calendar's `location/1` does.

  ### Returns

  * `true` if a leap month falls in that span, otherwise `false`.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> new_year = Date.to_gregorian_days(~D[2023-01-22])
      iex> Calendrical.Lunisolar.prior_leap_month?(new_year, Date.to_gregorian_days(~D[2023-05-19]), location)
      true
      iex> Calendrical.Lunisolar.prior_leap_month?(new_year, Date.to_gregorian_days(~D[2023-02-20]), location)
      false

  """
  def prior_leap_month?(m_prime, m, location_fun) when m >= m_prime do
    no_major_solar_term?(m, location_fun) ||
      prior_leap_month?(m_prime, new_moon_before(m, location_fun), location_fun)
  end

  def prior_leap_month?(_m_prime, _m, _location_fun) do
    false
  end

  @doc """
  Returns the name of a year in the Lunar sexagesimal cycle, as its
  celestial stem and terrestrial branch.

  ### Arguments

  * `year` is a position in the sexagesimal cycle, a lunisolar date as
    `{year, month, day}` or a traditional date as
    `{cycle, cyclical_year, month, leap_month?, day}`.

  ### Returns

  * `{stem, branch}`, the stem 1 to 10 and the branch 1 to 12.

  ### Examples

      iex> Calendrical.Lunisolar.stem_and_branch(40)
      {10, 4}
      iex> Calendrical.Lunisolar.stem_and_branch({4660, 1, 1})
      {10, 4}

  """
  def stem_and_branch({_cycle, cyclical_year, _month, _leap_month?, _day}) do
    stem_and_branch(cyclical_year)
  end

  def stem_and_branch({year, _month, _day}) do
    {_cycle, year} = cycle_and_year(year)
    stem_and_branch(year)
  end

  def stem_and_branch(n) do
    name(amod(n, 10), amod(n, 12))
  end

  defp name(stem, branch) when rem(stem, 2) == rem(branch, 2) do
    {stem, branch}
  end

  defp stem({stem, _branch}) do
    stem
  end

  defp branch({_stem, branch}) do
    branch
  end

  @doc """
  Returns the number of names from one Lunar name to the next
  occurrence of another.

  ### Arguments

  * `c_name1` is a `{stem, branch}` name.

  * `c_name2` is a `{stem, branch}` name.

  ### Returns

  * The number of names, 1 to 60.

  ### Examples

      iex> Calendrical.Lunisolar.name_difference({1, 1}, {10, 4})
      39

  """
  def name_difference(c_name1, c_name2) do
    stem1 = stem(c_name1)
    stem2 = stem(c_name2)

    branch1 = branch(c_name1)
    branch2 = branch(c_name2)

    stem_difference = stem2 - stem1
    branch_difference = branch2 - branch1

    1 + mod(stem_difference - 1 + 25 * (branch_difference - stem_difference), @years_in_cycle)
  end

  @doc """
  Returns the sexagesimal name of a month of a Chinese year.

  ### Arguments

  * `month` is a month of the year.

  * `year` is a year of the Chinese calendar.

  ### Returns

  * `{stem, branch}`.

  ### Examples

      iex> Calendrical.Lunisolar.month_name(1, 4660)
      {1, 3}

  """
  def month_name(month, year) do
    elapsed_months = 12 * (year - 1) + (month - 1)
    stem_and_branch(elapsed_months - @month_name_epoch)
  end

  @doc """
  Returns the sexagesimal name of a day.

  ### Arguments

  * `date` is an ISO day number.

  ### Returns

  * `{stem, branch}`.

  ### Examples

      # 22 January 2023, Chinese New Year, was a 庚辰 day
      iex> Calendrical.Lunisolar.day_name(738_907)
      {7, 5}

  """
  def day_name(date) do
    stem_and_branch(date - @day_name_epoch)
  end

  @doc """
  Returns the latest day on or before `date` that has the given
  sexagesimal name.

  ### Arguments

  * `name` is a `{stem, branch}` name.

  * `date` is an ISO day number.

  ### Returns

  * The ISO day number of that day.

  ### Examples

      iex> Calendrical.Lunisolar.day_name_on_or_before({1, 1}, 738_907)
      738891

  """
  # A day has the name whose place in the cycle is its distance from the
  # day name epoch; the place of `name` is its steps on from the cycle's
  # sixtieth name, `{10, 12}`.
  def day_name_on_or_before(name, date) do
    place = name_difference(stem_and_branch(@years_in_cycle), name)
    date - mod(date - @day_name_epoch - place, @years_in_cycle)
  end

  @doc """
  Returns the place a lunisolar calendar is reckoned at on a day, as
  the point Astro takes.

  ### Arguments

  * `iso_days` is an ISO day number.

  * `location_fun` is a 1-arity function of the ISO day number that
    returns `{latitude, longitude, altitude, offset}`, as a calendar's
    `location/1` does.

  ### Returns

  * A `Geo.PointZ` of the longitude, latitude and altitude, with the
    offset from UTC, in days, as its `:offset` property.

  ### Examples

      iex> location = &Calendrical.Chinese.location/1
      iex> %Geo.PointZ{properties: %{offset: offset}} = Calendrical.Lunisolar.location(738_907, location)
      iex> offset
      0.3333333333333333

  """
  def location(iso_days, location_fun) do
    {latitude, longitude, altitude, offset} = location_fun.(iso_days)
    properties = %{offset: offset}
    %Geo.PointZ{coordinates: {longitude, latitude, altitude}, properties: properties}
  end
end
