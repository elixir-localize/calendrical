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

  @doc """
  Create a new date in the lunisolar calendar.

  ### Arguments

  * `year` is a year in the lunisolar calendar.

  * `month` is a month in the lunisolar calendar
  as either a positive integer or a tuple of the
  form `{month, :leap}` representing the leap month.

  * `day` is a day of month.

  * `epoch` is the epoch in iso days for the lunisolar
    calendar.

  * `location_fun` is a 1-arity function that returns
    the tuple of the form `{latitude, longitude, altitude, hour_offset}`
    for  the lunisolar calendar.

  ### Returns

  * `iso_days` begin the iso_days for the given date in
    based upon the given location.

  """

  def new(year, {lunar_month, :leap} = month, day, epoch, location_fun) do
    if valid_traditional_date?(year, month, day, epoch, location_fun) do
      {cycle, cyclical_year} = cycle_and_year(year)
      leap_month? = true

      alt_cyclical_date_to_iso_days(
        cycle,
        cyclical_year,
        lunar_month,
        leap_month?,
        day,
        epoch,
        location_fun
      )
    else
      {:error, :invalid_date}
    end
  end

  def new(year, month, day, epoch, location_fun) do
    if valid_traditional_date?(year, month, day, epoch, location_fun) do
      {cycle, cyclical_year} = cycle_and_year(year)
      leap_month? = false

      alt_cyclical_date_to_iso_days(
        cycle,
        cyclical_year,
        month,
        leap_month?,
        day,
        epoch,
        location_fun
      )
    else
      {:error, :invalid_date}
    end
  end

  @doc """
  Returns the Gregorian date for the lunar month and day in a
  given Gregorian year.

  """
  def gregorian_date_for_lunar(gregorian_year, lunar_month, lunar_day, epoch, location_fun) do
    mid_year = Calendar.ISO.date_to_iso_days(gregorian_year, 7, 1)

    {cycle, cyclic_year, _month, _day} =
      cyclical_date_from_iso_days(mid_year, epoch, location_fun)

    iso_days =
      alt_cyclical_date_to_iso_days(
        cycle,
        cyclic_year,
        lunar_month,
        lunar_day,
        epoch,
        location_fun
      )

    Calendar.ISO.date_from_iso_days(iso_days)
  end

  @doc false
  @spec cyclic_year(integer, Calendar.month(), Calendar.day()) :: integer
  def cyclic_year(year, _month, _day) when is_integer(year) do
    {_cycle, year} = cycle_and_year(year)
    year
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

  # Validity check used by `new/5` to vet user-supplied **traditional** lunar
  # months. Distinct from the 3-arity `valid_date?/3` callback that
  # `Date.new/4` calls (which is supplied by `Calendrical.Behaviour` and uses
  # ordinal month numbering). The two functions answer different questions —
  # see the moduledoc of each wrapper calendar (LunarJapanese / Chinese /
  # Korean) for the ordinal-vs-traditional discussion.

  defp valid_traditional_date?(year, lunar_month, day, epoch, location_fun)
       when is_integer(lunar_month) do
    lunar_month <= @lunar_calendar_months_in_year &&
      day <= days_in_lunar_month(year, lunar_month, epoch, location_fun)
  end

  defp valid_traditional_date?(year, {lunar_month, :leap}, day, epoch, location_fun)
       when is_integer(lunar_month) do
    # `leap_month/3` returns the *ordinal* position of the intercalary month in
    # the 1..13 sequence. The traditional notation `{M, :leap}` uses the
    # *traditional* number, which is always the ordinal position minus one
    # (the leap month repeats the preceding traditional month number; the lunar
    # new year is always anchored on a non-leap month, so the ordinal is ≥ 2).
    case leap_month(year, epoch, location_fun) do
      nil ->
        false

      ordinal_leap when ordinal_leap - 1 == lunar_month ->
        day <= days_in_lunar_month(year, {lunar_month, :leap}, epoch, location_fun)

      _ ->
        false
    end
  end

  @doc """
  Returns if the given year is a leap
  year.

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

  """

  def leap_year?(year, epoch, location_fun) do
    {{new_year, _leap_sui?}, _next_solstice, {next_new_year, _next_leap_sui?}} =
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

  """
  def leap_month?(year, month, epoch, location_fun) do
    {cycle, cyclic_year} = cycle_and_year(year)
    leap_month?(cycle, cyclic_year, month, epoch, location_fun)
  end

  @first_day_of_month 1

  def leap_month?(cycle, cyclical_year, month, epoch, location_fun) do
    start_of_month =
      cyclical_date_to_iso_days(
        cycle,
        cyclical_year,
        month,
        @first_day_of_month,
        epoch,
        location_fun
      )

    new_year = new_year_on_or_before(start_of_month, location_fun)

    leap_lunisolar_year?(start_of_month, location_fun) &&
      no_major_solar_term?(start_of_month, location_fun) &&
      !prior_leap_month?(start_of_month, new_year, location_fun)
  end

  @doc """
  Returns the leap month number for a given year
  or nil if its not a leap year.

  """
  def leap_month(year, epoch, location_fun) do
    {{new_year, leap_sui?}, next_solstice, {next_new_year, next_leap_sui?}} =
      year_suis(year, epoch, location_fun)

    if thirteen_months?(new_year, next_new_year) do
      # Month 1 is never the leap month, so the search starts at month 2.
      second_month = new_moon_on_or_after(new_year + 1, location_fun)
      term = current_major_solar_term(second_month, location_fun)
      suis = {next_solstice, leap_sui?, next_leap_sui?}
      first_leap_month(2, second_month, term, suis, location_fun)
    end
  end

  # The first month, from ordinal `month` starting on `start` (whose major
  # solar term is `term`), that lies in a leap sui and has no major solar
  # term of its own. A month belongs to the sui of the December solstice on
  # or before its first day.
  defp first_leap_month(month, _start, _term, _suis, _location_fun)
       when month > @lunar_calendar_months_in_year + 1 do
    nil
  end

  defp first_leap_month(month, start, term, suis, location_fun) do
    {next_solstice, leap_sui?, next_leap_sui?} = suis
    next_start = new_moon_on_or_after(start + 1, location_fun)
    next_term = current_major_solar_term(next_start, location_fun)
    in_leap_sui? = if start < next_solstice, do: leap_sui?, else: next_leap_sui?

    if in_leap_sui? and term == next_term do
      month
    else
      first_leap_month(month + 1, next_start, next_term, suis, location_fun)
    end
  end

  # Version which uses ordinal numbers in a monotonic sequence 1..12
  # or 1..13 for month numbers. Leap months are not marked but can
  # be later calculated.

  # This makes clear how simple the calendar is - just a sequence of
  # months aligned to new moons. The complication is only determining
  # the start of the year and leap months.

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
  # the next year's new year falls in, as `{new_year, leap_sui?}` each, with
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

  # Here we return months that monotonically increase
  # from 1 to 12 (or 13 in a leap year).
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

    elapsed_years =
      ((new_year - epoch) / Time.mean_tropical_year() + 1)
      |> round()

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
  def elapsed_years(cycle, cyclic_year) do
    (cycle - 1) * @years_in_cycle + cyclic_year
  end

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

  defp days_in_lunar_month(year, lunar_month, epoch, location_fun) do
    case lunar_month_to_calendar_month(year, lunar_month, epoch, location_fun) do
      {:ok, month} ->
        days_in_month(year, month, epoch, location_fun)

      {:error, reason} ->
        {:error, reason}
    end
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
    {{new_year, _leap_sui?}, _next_solstice, {next_new_year, _next_leap_sui?}} =
      year_suis(year, epoch, location_fun)

    next_new_year - new_year
  end

  @doc false
  # The `Calendar.valid_date?/3` answer for an ordinal date: the month is in
  # the year and the day in the month. Months 1..12 are in every year, so only
  # month 13 needs the next new year.
  def valid_date?(_year, month, _day, _epoch, _location_fun)
      when month > @lunar_calendar_months_in_year + 1 do
    false
  end

  def valid_date?(year, 13, day, epoch, location_fun) do
    {{new_year, _leap_sui?}, _next_solstice, {next_new_year, _next_leap_sui?}} =
      year_suis(year, epoch, location_fun)

    thirteen_months?(new_year, next_new_year) and
      day <= next_new_year - month_start(new_year, 13, location_fun)
  end

  def valid_date?(year, month, day, epoch, location_fun) do
    day <= days_in_month(year, month, epoch, location_fun)
  end

  # `leap_month/3` is `nil` unless the year is a leap year.
  defp lunar_month_to_calendar_month(year, lunar_month, epoch, location_fun)
       when is_integer(lunar_month) and lunar_month in 1..@lunar_calendar_months_in_year do
    case leap_month(year, epoch, location_fun) do
      leap_month when is_integer(leap_month) and leap_month < lunar_month ->
        {:ok, lunar_month + 1}

      _other ->
        {:ok, lunar_month}
    end
  end

  defp lunar_month_to_calendar_month(year, {lunar_month, :leap}, epoch, location_fun)
       when is_integer(lunar_month) and lunar_month in 1..@lunar_calendar_months_in_year do
    case leap_month(year, epoch, location_fun) do
      ^lunar_month -> {:ok, lunar_month}
      _other -> {:error, :invalid_leap_month}
    end
  end

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
  # epoch is itself a new year. For an epoch mid-year (Calendrical.LunarJapanese
  # counts from 645-07-20) it lands between the December solstice and the
  # new year, so every lookup computed two sui instead of one, and for an
  # epoch in late July or August it duplicated or skipped years.
  # Snapping to the nearest mean mid-lunar-year keeps the year the
  # estimate points into while staying months clear of either new year.
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
  will be 'lambda' degrees.

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

  * `{:error, {:invalid_solar_term, index}}` when `index` is not in `1..24`.

  ### Examples

      iex> Calendrical.Lunisolar.solar_term(5, 2025, &Calendrical.Chinese.location/1)
      {:ok, ~D[2025-04-04 Calendrical.Gregorian]}

  """
  def solar_term(index, gregorian_year, location_fun) when index in 1..24 do
    longitude = rem(300 + index * 15, 360)
    start = Calendrical.Gregorian.date_to_iso_days(gregorian_year, 1, 1)
    moment = solar_longitude_on_or_after(longitude, start, location_fun)
    {year, month, day} = Calendrical.Gregorian.date_from_iso_days(trunc(moment))
    Date.new(year, month, day, Calendrical.Gregorian)
  end

  def solar_term(index, _gregorian_year, _location_fun) do
    {:error, {:invalid_solar_term, index}}
  end

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

  @doc """
  The name of the solar term (jié-qì) at a 1-based index.

  The 24 solar terms are numbered from `lichun` (立春, index 1) at 315° solar
  ecliptic longitude, then every 15° — the same order `solar_term/3` computes a
  term's date for, so an index that dates a term also names it.

  ### Arguments

  * `index` is the 1-based solar-term number, `1..24`.

  ### Returns

  * `{:ok, name}` with the term's romanised (pinyin) name, such as `"qingming"`.

  * `{:error, {:invalid_solar_term, index}}` when `index` is not in `1..24`.

  ### Examples

      iex> Calendrical.Lunisolar.solar_term_name(1)
      {:ok, "lichun"}

      iex> Calendrical.Lunisolar.solar_term_name(5)
      {:ok, "qingming"}

      iex> Calendrical.Lunisolar.solar_term_name(22)
      {:ok, "dongzhi"}

      iex> Calendrical.Lunisolar.solar_term_name(0)
      {:error, {:invalid_solar_term, 0}}

  """
  @spec solar_term_name(integer()) ::
          {:ok, String.t()} | {:error, {:invalid_solar_term, integer()}}
  def solar_term_name(index) when is_integer(index) and index in 1..24 do
    {:ok, elem(@solar_term_names, index - 1)}
  end

  def solar_term_name(index) do
    {:error, {:invalid_solar_term, index}}
  end

  @doc """
  Return last Chinese major solar term (zhongqi) before
  `iso_days`.

  """
  def current_major_solar_term(iso_days, location_fun) do
    {_lat, _lng, _alt, offset} = location_fun.(iso_days)
    d = Time.universal_from_standard(iso_days, offset)
    s = Solar.solar_ecliptic_longitude(d)
    amod(2 + floor(trunc(s) / deg(30)), 12)
  end

  @doc """
  Return moment at `location` of the first major
  solar term (zhongqi) on or after `iso_days`.  The
  major terms begin when the sun's longitude is a
  multiple of 30 degrees.

  """
  def major_solar_term_on_or_after(iso_days, location_fun) do
    s = Solar.solar_ecliptic_longitude(midnight_in_location(iso_days, location_fun))
    l = mod(30 * ceil(s / 30), 360)
    solar_longitude_on_or_after(l, iso_days, location_fun)
  end

  @doc """
  Return last minor solar term (jieqi) before `iso_days`.
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
  Return moment at `location` of the first minor solar
  term (jieqi) on or after `iso_days`.  The minor terms
  begin when the sun's longitude is an odd multiple of 15 degrees.

  """
  def minor_solar_term_on_or_after(iso_days, location_fun) do
    s = Solar.solar_ecliptic_longitude(midnight_in_location(iso_days, location_fun))
    l = mod(30 * ceil((s - deg(15)) / 30) + deg(15), 360)

    solar_longitude_on_or_after(l, iso_days, location_fun)
  end

  @doc """
  Return `iso_day` at `location` of first new moon
  before `iso_days`.

  """
  def new_moon_before(iso_days, location_fun) do
    new_moon =
      iso_days
      |> midnight_in_location(location_fun)
      |> Lunar.date_time_new_moon_before()

    {_lat, _lng, _alt, offset} = location_fun.(new_moon)

    Time.standard_from_universal(new_moon, offset) |> floor()
  end

  @doc """
  Return `iso_day` at `location` of first new moon on or after
  `iso_days`.

  """
  def new_moon_on_or_after(iso_days, location_fun) do
    new_moon =
      iso_days
      |> midnight_in_location(location_fun)
      |> Lunar.date_time_new_moon_at_or_after()

    {_lat, _lng, _alt, offset} = location_fun.(new_moon)

    Time.standard_from_universal(new_moon, offset) |> floor()
  end

  @doc """
  Return `true` if lunar month starting on `iso_days`
  at `location` has no major solar term.

  """
  def no_major_solar_term?(iso_days, location_fun) do
    new_moon = new_moon_on_or_after(iso_days + 1, location_fun)

    current_major_solar_term(iso_days, location_fun) ==
      current_major_solar_term(new_moon, location_fun)
  end

  @doc """
  Return Universal time of (clock) midnight at start of `iso_days`,
  at `location`.

  """
  def midnight_in_location(iso_days, location_fun) do
    {_lat, _lng, _alt, offset} = location_fun.(iso_days)
    Time.universal_from_standard(iso_days, offset)
  end

  @doc """
  Return iso_days, in the `location` zone, of winter solstice
  on or before `iso_days`.

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
  Return `iso_day` of Lunar New Year in sui
  (period from solstice to solstice)
  containing `iso_days`.

  """
  def new_year_in_sui(iso_days, location_fun) do
    solstice = december_solstice_on_or_before(iso_days, location_fun)

    {new_year, _leap_sui?} =
      sui(solstice, next_december_solstice(solstice, location_fun), location_fun)

    new_year
  end

  @doc """
  Return `iso_day` of Lunar New Year on or
  before `iso_days` at `location`.

  """
  def new_year_on_or_before(iso_days, location_fun) do
    solstice = december_solstice_on_or_before(iso_days, location_fun)

    {new_year, _leap_sui?} =
      sui(solstice, next_december_solstice(solstice, location_fun), location_fun)

    if iso_days >= new_year do
      new_year
    else
      # `iso_days` lies between the solstice and the new year after it, so its
      # new year is that of the previous sui, which ends at this solstice.
      previous_solstice = december_solstice_on_or_before(iso_days - 180, location_fun)
      {previous_new_year, _leap_sui?} = sui(previous_solstice, solstice, location_fun)
      previous_new_year
    end
  end

  # The December solstice a year after `solstice`.
  defp next_december_solstice(solstice, location_fun) do
    december_solstice_on_or_before(solstice + @one_solar_year_later, location_fun)
  end

  # The sui from the December solstice `solstice` to `next_solstice`, as
  # `{new_year, leap_sui?}`. Month 12 begins with the first new moon after the
  # solstice and the new year usually with the next (month 13 of the old
  # count). In a leap sui — 13 new moons from month 12 to the next month 11 —
  # the new year moves one month later when month 12 or the month after it
  # has no major solar term, since that month is the sui's leap month.
  defp sui(solstice, next_solstice, location_fun) do
    month_12 = new_moon_on_or_after(1 + solstice, location_fun)
    next_month_11 = new_moon_before(1 + next_solstice, location_fun)
    month_13 = new_moon_on_or_after(1 + month_12, location_fun)
    leap_sui? = leap_lunisolar_year?(month_12, next_month_11)

    if leap_sui? do
      {leap_sui_new_year(month_12, month_13, location_fun), leap_sui?}
    else
      {month_13, leap_sui?}
    end
  end

  defp leap_sui_new_year(month_12, month_13, location_fun) do
    month_14 = new_moon_on_or_after(1 + month_13, location_fun)
    term_12 = current_major_solar_term(month_12, location_fun)
    term_13 = current_major_solar_term(month_13, location_fun)

    if term_12 == term_13 or term_13 == current_major_solar_term(month_14, location_fun) do
      month_14
    else
      month_13
    end
  end

  @doc """
  Return iso_days of Lunar New Year at `location` for a
  Gregorian year.

  """
  def chinese_new_year_for_gregorian_year(gregorian_year, location_fun) do
    iso_days = Calendrical.Gregorian.date_to_iso_days(gregorian_year, 7, 1)
    new_year_on_or_before(iso_days, location_fun)
  end

  @doc """
  Return `true` if there is a Lunar leap month on or after lunar
  month starting on `m_prime` and at or before
  lunar month starting at `m`.

  """
  def prior_leap_month?(m_prime, m, location_fun) when m >= m_prime do
    no_major_solar_term?(m, location_fun) ||
      prior_leap_month?(m_prime, new_moon_before(m, location_fun), location_fun)
  end

  def prior_leap_month?(_m_prime, _m, _location_fun) do
    false
  end

  @doc """
  Return the name of the Lunar
  sexagesimal cycle.

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
  Return the number of names from Lunar name c_name1 to the
  next occurrence of Lunar name c_name2.

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

  # CHECK THIS was iso_day(45) -> might need to be +/- 365 since our
  # epoch is different
  @month_name_epoch 57

  @doc """
  Return sexagesimal name for month, month, of Chinese year, year.
  """
  def month_name(month, year) do
    elapsed_months = 12 * (year - 1) + (month - 1)
    stem_and_branch(elapsed_months - @month_name_epoch)
  end

  # CHECK THIS was iso_day(45) -> might need to be +/- 365 since our
  # epoch is different
  @day_name_epoch 45

  @doc """
  Return sexagesimal name for date, date.
  """
  def day_name(date) do
    stem_and_branch(date - @day_name_epoch)
  end

  @doc """
  Return iso_days of latest date on or before iso_days, that
  has Chinese name, name.

  """
  def day_name_on_or_before(name, date) do
    name_difference = name_difference(name, stem_and_branch(@day_name_epoch))
    date - mod(date + name_difference, @years_in_cycle)
  end

  def location(iso_days, location_fun) do
    {latitude, longitude, altitude, offset} = location_fun.(iso_days)
    properties = %{offset: offset}
    %Geo.PointZ{coordinates: {longitude, latitude, altitude}, properties: properties}
  end
end
