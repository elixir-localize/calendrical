defmodule Calendrical.Islamic.UmmAlQura do
  @moduledoc """
  Implementation of the Saudi Arabian Umm al-Qura calendar.

  The Umm al-Qura (أم القرى, "Mother of Towns" — a name for Mecca) calendar
  is the official Hijri calendar of the Kingdom of Saudi Arabia and the
  basis for date calculations published by the King Abdulaziz City for
  Science and Technology (KACST). It differs from the purely tabular
  Hijri calendars (`Calendrical.Islamic.Civil` and
  `Calendrical.Islamic.Tbla`) in that the start of each month is
  determined by an astronomical observation rule applied at Mecca rather
  than by a fixed arithmetic cycle. Individual months may therefore
  deviate from the tabular value by up to a day.

  This module embeds the official KACST Umm al-Qura tables (sourced from
  R.H. van Gent's Utrecht University dataset, cross-referenced against
  the KACST publications) at compile time. Every conversion between an
  Umm al-Qura date and a Gregorian date is therefore an O(log n) lookup
  with no floating-point arithmetic at runtime.

  ## Coverage

  The embedded data covers approximately **1356 AH through ~1500 AH**
  (March 1937 CE through ~2076 CE). Dates outside this range raise
  `Calendrical.IslamicYearOutOfRangeError` from `date_to_iso_days/3` and
  `date_from_iso_days/1`.

  Days begin at midnight by default. `date_at/2` maps an absolute instant to
  the Hijri date under a chosen day-start convention — midnight, an 18:00
  proxy, or true sunset (Maghrib) at Mecca.

  ## Reference

  - R.H. van Gent, "The Umm al-Qura Calendar of Saudi Arabia",
    <https://webspace.science.uu.nl/~gent0113/islam/ummalqura.htm>
  - KACST published Umm al-Qura tables.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-07-19 Calendrical.Gregorian],
    cldr_calendar_type: :islamic_umalqura,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12,
    first_day_of_week: 7

  alias Calendrical.Islamic.UmmAlQura.ReferenceData

  @type year :: pos_integer()
  @type month :: 1..12
  @type day :: 1..30

  # Compile-time lookup tables built from the official Umm al-Qura
  # reference data. Two structures are produced:
  #
  #   * `@first_day_iso` — a map from `{year, month}` to the ISO day
  #     number of 1 Hijri-month, used for forward conversion.
  #
  #   * `@reverse_lookup` — a tuple of `{first_iso_days, year, month}`
  #     entries sorted by `first_iso_days`, used by `date_from_iso_days/1`
  #     to find the month containing a given ISO day. Stored as a tuple
  #     so binary search can be performed in O(log n) at runtime.

  @reference_dates ReferenceData.umm_al_qura_dates()
                   |> Enum.map(fn %{hijri_year: y, hijri_month: m, gregorian: d} ->
                     %{hijri_year: y, hijri_month: m, iso_days: Date.to_gregorian_days(d)}
                   end)

  @first_day_iso Map.new(@reference_dates, fn %{
                                                hijri_year: y,
                                                hijri_month: m,
                                                iso_days: i
                                              } ->
                   {{y, m}, i}
                 end)

  @reverse_lookup @reference_dates
                  |> Enum.sort_by(& &1.iso_days)
                  |> Enum.map(fn %{hijri_year: y, hijri_month: m, iso_days: i} ->
                    {i, y, m}
                  end)
                  |> List.to_tuple()

  @reverse_size tuple_size(@reverse_lookup)

  @min_year @reference_dates |> Enum.map(& &1.hijri_year) |> Enum.min()

  # The literal maximum year in the data may have only Muharram (month 1)
  # present as a sentinel used to compute the length of the previous
  # year's Dhu al-Hijja. The "usable" maximum year is the highest year
  # for which all 12 months are present in the lookup table.
  @max_year @reference_dates
            |> Enum.group_by(& &1.hijri_year)
            |> Enum.filter(fn {_y, entries} -> length(entries) == 12 end)
            |> Enum.map(fn {y, _} -> y end)
            |> Enum.max()

  @min_iso_days Map.fetch!(
                  Map.new(@reference_dates, fn %{
                                                 hijri_year: y,
                                                 hijri_month: m,
                                                 iso_days: i
                                               } ->
                    {{y, m}, i}
                  end),
                  {@min_year, 1}
                )

  @max_iso_days (
                  forward =
                    Map.new(@reference_dates, fn %{
                                                   hijri_year: y,
                                                   hijri_month: m,
                                                   iso_days: i
                                                 } ->
                      {{y, m}, i}
                    end)

                  last_first = Map.fetch!(forward, {@max_year, 12})
                  next_first = Map.get(forward, {@max_year + 1, 1})

                  if next_first, do: next_first - 1, else: last_first + 29
                )

  # Great Mosque of Mecca (al-Masjid al-Ḥarām) — the reference location for
  # the Umm al-Qura calendar, matching Calendrical.Islamic.UmmAlQura.Astronomical.
  @mecca_location %Geo.PointZ{coordinates: {39.8262, 21.4225, 277.0}}

  # Saudi Arabia observes UTC+3 all year (no daylight saving).
  @mecca_utc_offset_seconds 3 * 60 * 60

  @evening_day_start ~T[18:00:00]

  @valid_day_starts [:midnight, :evening, :mecca_sunset]

  @doc """
  Returns the Umm al-Qura date in effect at a given instant, under a chosen
  day-start convention.

  The Islamic day traditionally begins at sunset, so after sunset the
  Umm al-Qura date is already the following day. This function maps an
  absolute instant to the Hijri date, choosing the day boundary with the
  `:day_start` option. All boundaries are evaluated **at Mecca** — where the
  Umm al-Qura calendar is defined — so the result is the official Hijri date
  for that instant regardless of the observer's own time zone.

  For the plain civil-day mapping (the calendar's default), convert a date
  directly with `Date.convert/2` instead.

  ### Arguments

  * `datetime` is a `t:DateTime.t/0` — an absolute instant. Its own time zone
    is used only to fix the instant; the day boundary is always taken at Mecca.

  ### Options

  * `:day_start` selects the moment the Umm al-Qura day begins:

    * `:midnight` (the default) — the day begins at 00:00 Mecca time, i.e. the
      ordinary civil-day mapping.

    * `:evening` — the day begins at 18:00 Mecca time, the fixed-clock proxy
      for sunset used by many implementations.

    * `:mecca_sunset` — the day begins at true sunset (Maghrib) at Mecca,
      computed astronomically via `Astro`. This is upper-limb sunset, which
      differs by a minute or two from the centre-of-disk sunset that
      `Calendrical.Islamic.UmmAlQura.Astronomical` uses to start each month.

  ### Returns

  * `{:ok, date}` — an Umm al-Qura `t:Date.t/0`.

  * `{:error, reason}` if the day-start option is invalid, the resulting date
    lies outside the embedded reference data, or sunset cannot be computed.

  ### Examples

      # Morning at Mecca: every convention agrees.
      iex> Calendrical.Islamic.UmmAlQura.date_at(~U[2025-03-01 06:00:00Z])
      {:ok, ~D[1446-09-01 Calendrical.Islamic.UmmAlQura]}

      # After sunset the evening convention has rolled to the next Hijri day.
      iex> Calendrical.Islamic.UmmAlQura.date_at(~U[2025-03-01 16:00:00Z], day_start: :evening)
      {:ok, ~D[1446-09-02 Calendrical.Islamic.UmmAlQura]}

  """
  @spec date_at(DateTime.t(), Keyword.t()) :: {:ok, Date.t()} | {:error, term()}
  def date_at(%DateTime{} = datetime, options \\ []) do
    day_start = Keyword.get(options, :day_start, :midnight)
    {mecca_date, mecca_time, instant} = mecca_wall_clock(datetime)

    with :ok <- validate_day_start(day_start),
         {:ok, roll} <- day_roll(day_start, mecca_date, mecca_time, instant) do
      mecca_date
      |> Date.add(roll)
      |> to_umm_al_qura()
    end
  end

  defp validate_day_start(day_start) when day_start in @valid_day_starts, do: :ok
  defp validate_day_start(other), do: {:error, {:invalid_day_start, other}}

  # Convert the instant to Mecca (UTC+3) wall-clock, returning its Gregorian
  # date, its time of day, and the original instant for absolute comparisons.
  defp mecca_wall_clock(%DateTime{} = datetime) do
    unix = DateTime.to_unix(datetime, :second)
    mecca = DateTime.from_unix!(unix + @mecca_utc_offset_seconds)
    {DateTime.to_date(mecca), DateTime.to_time(mecca), datetime}
  end

  defp day_roll(:midnight, _date, _time, _instant), do: {:ok, 0}

  defp day_roll(:evening, _date, mecca_time, _instant) do
    if Time.compare(mecca_time, @evening_day_start) in [:eq, :gt] do
      {:ok, 1}
    else
      {:ok, 0}
    end
  end

  defp day_roll(:mecca_sunset, mecca_date, _mecca_time, instant) do
    case Astro.sunset(@mecca_location, mecca_date, time_zone: :utc) do
      {:ok, sunset} ->
        if DateTime.compare(instant, sunset) in [:eq, :gt], do: {:ok, 1}, else: {:ok, 0}

      {:error, _reason} ->
        {:error, :no_sunset}
    end
  end

  defp to_umm_al_qura(%Date{} = gregorian_date) do
    Date.convert(gregorian_date, __MODULE__)
  rescue
    error in Calendrical.IslamicYearOutOfRangeError -> {:error, error}
  end

  @doc """
  Returns the first Hijri year covered by the embedded Umm al-Qura
  reference data.
  """
  # The literal bound of the shipped reference table; dialyzer
  # keeps this spec synchronized with the data.
  @spec min_year() :: 1356
  def min_year, do: @min_year

  @doc """
  Returns the last Hijri year covered by the embedded Umm al-Qura
  reference data.
  """
  # The literal bound of the shipped reference table; dialyzer
  # keeps this spec synchronized with the data.
  @spec max_year() :: 1500
  def max_year, do: @max_year

  @doc """
  Returns the Gregorian `t:Calendar.date/0` of the first day of the given
  Hijri month according to the official Umm al-Qura tables.

  Returns `{:error, %Calendrical.IslamicYearOutOfRangeError{}}` if the
  requested month falls outside the embedded data range.

  """
  @spec first_day_of_month(year, month) ::
          {:ok, Date.t()} | {:error, Exception.t()}
  def first_day_of_month(hijri_year, hijri_month)
      when is_integer(hijri_year) and is_integer(hijri_month) and hijri_month in 1..12 do
    case Map.get(@first_day_iso, {hijri_year, hijri_month}) do
      nil ->
        {:error,
         Calendrical.IslamicYearOutOfRangeError.exception(
           year: hijri_year,
           min_year: @min_year,
           max_year: @max_year
         )}

      iso_days ->
        {:ok, Date.from_gregorian_days(iso_days)}
    end
  end

  def first_day_of_month(_year, _month) do
    {:error,
     Calendrical.IslamicYearOutOfRangeError.exception(
       year: nil,
       min_year: @min_year,
       max_year: @max_year
     )}
  end

  @doc """
  Determines if the given Umm al-Qura date is valid.

  A date is valid if its `year` falls within the embedded reference
  range, its `month` is in `1..12`, and its `day` is between 1 and the
  number of days in that month according to the published tables.
  """
  @impl true
  def valid_date?(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) and
             year >= @min_year and year <= @max_year and
             month in 1..12 and day in 1..30 do
    day <= days_in_month(year, month)
  end

  def valid_date?(_year, _month, _day), do: false

  @doc """
  Returns whether the given Hijri `year` is a leap year (355 days).
  """
  @impl true
  def leap_year?(year) do
    case days_in_year_lookup(year) do
      {:ok, 355} -> true
      _ -> false
    end
  end

  @doc """
  Returns the number of days in the given Hijri `year` (354 or 355).
  """
  @impl true
  def days_in_year(year) do
    case days_in_year_lookup(year) do
      {:ok, days} -> days
      :error -> raise out_of_range_error(year)
    end
  end

  @doc """
  Returns `{year, week_in_year}` for the given Umm al-Qura date.

  Weeks run Sunday (al-Ahad, “the first”) through Saturday, the
  calendar's own week boundary. Week 1 is the week containing
  1 Muharram, so a year that opens mid-week has a short
  first week. Every date numbers within its own year; weeks do
  not spill into the adjacent year's numbering.

  ### Arguments

  * `year` is any Umm al-Qura year as an integer.

  * `month` is a Umm al-Qura month number.

  * `day` is a Umm al-Qura day-of-month.

  ### Returns

  * A two-tuple `{year, week_in_year}`.

  ### Examples

      iex> Calendrical.Islamic.UmmAlQura.week_of_year(1447, 1, 1)
      {1447, 1}

      iex> Calendrical.Islamic.UmmAlQura.week_of_year(1447, 9, 1)
      {1447, 35}

  """
  @impl true
  @spec week_of_year(Calendar.year(), Calendar.month(), Calendar.day()) ::
          {Calendar.year(), Calendar.week()}
  def week_of_year(year, month, day) do
    Calendrical.Base.Common.week_of_year(__MODULE__, year, month, day)
  end

  @doc """
  Returns the number of weeks in the given Umm al-Qura `year`.

  ### Arguments

  * `year` is any Umm al-Qura year as an integer.

  ### Returns

  * A two-tuple `{weeks_in_year, days_in_last_week}` where the
    final week is short when the year does not end on the last
    day of the calendar's week.

  ### Examples

      iex> Calendrical.Islamic.UmmAlQura.weeks_in_year(1447)
      {52, 2}

  """
  @impl true
  @spec weeks_in_year(Calendar.year()) :: {Calendrical.week(), Calendar.day()}
  def weeks_in_year(year) do
    Calendrical.Base.Common.weeks_in_year(__MODULE__, year)
  end

  @doc """
  Returns the number of days in the given Hijri `year` and `month`.
  Months are 29 or 30 days as determined by the published Umm al-Qura
  tables.
  """
  @impl true
  @spec days_in_month(year, month) :: 29..30
  def days_in_month(year, month) when month in 1..12 do
    case days_in_month_lookup(year, month) do
      {:ok, days} -> days
      :error -> raise out_of_range_error(year)
    end
  end

  @doc """
  Returns the number of ISO days for the given Umm al-Qura
  `year`, `month`, and `day`.

  Raises `Calendrical.IslamicYearOutOfRangeError` if the date is
  outside the embedded reference range.
  """
  @spec date_to_iso_days(year, month, day) :: integer()
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    case Map.fetch(@first_day_iso, {year, month}) do
      {:ok, first} when is_integer(first) -> first + day - 1
      :error -> raise out_of_range_error(year)
    end
  end

  @doc """
  Returns the Umm al-Qura `{year, month, day}` for the given ISO day
  number.

  Raises `Calendrical.IslamicYearOutOfRangeError` if `iso_days` is
  outside the embedded reference range.
  """
  @spec date_from_iso_days(integer()) :: {year, month, day}
  def date_from_iso_days(iso_days)
      when is_integer(iso_days) and iso_days >= @min_iso_days and iso_days <= @max_iso_days do
    {first, year, month} = binary_search(iso_days, 0, @reverse_size - 1)
    {year, month, iso_days - first + 1}
  end

  def date_from_iso_days(_iso_days) do
    raise Calendrical.IslamicYearOutOfRangeError.exception(
            year: nil,
            min_year: @min_year,
            max_year: @max_year
          )
  end

  # ── Internal helpers ──────────────────────────────────────────────────────

  defp days_in_year_lookup(year) do
    with {:ok, first} <- Map.fetch(@first_day_iso, {year, 1}),
         {:ok, next_first} <- next_year_first_day(year) do
      {:ok, next_first - first}
    end
  end

  defp next_year_first_day(year) do
    case Map.fetch(@first_day_iso, {year + 1, 1}) do
      {:ok, _} = ok ->
        ok

      :error ->
        # The very last year in the table has no successor; estimate
        # using its 12th-month start + days_in_month(year, 12).
        with {:ok, m12_first} <- Map.fetch(@first_day_iso, {year, 12}),
             {:ok, m12_days} <- days_in_month_lookup(year, 12) do
          {:ok, m12_first + m12_days}
        end
    end
  end

  defp days_in_month_lookup(year, 12) do
    with {:ok, first} <- Map.fetch(@first_day_iso, {year, 12}),
         {:ok, next} <- Map.fetch(@first_day_iso, {year + 1, 1}) do
      {:ok, next - first}
    else
      :error ->
        # Trailing month — fall back to the synodic-month average
        # rounded to 29 or 30 days.
        case Map.fetch(@first_day_iso, {year, 12}) do
          {:ok, _} -> {:ok, 29}
          :error -> :error
        end
    end
  end

  defp days_in_month_lookup(year, month) when month in 1..11 do
    with {:ok, first} <- Map.fetch(@first_day_iso, {year, month}),
         {:ok, next} <- Map.fetch(@first_day_iso, {year, month + 1}) do
      {:ok, next - first}
    end
  end

  # Binary search the @reverse_lookup tuple for the entry with the
  # largest first_iso_days that is ≤ iso_days. Returns the matching
  # `{first, year, month}` triple.
  defp binary_search(target, low, high) when low <= high do
    mid = div(low + high, 2)
    {first, _, _} = entry = elem(@reverse_lookup, mid)

    cond do
      first == target ->
        entry

      first < target ->
        if mid == high or elem(@reverse_lookup, mid + 1) |> elem(0) > target do
          entry
        else
          binary_search(target, mid + 1, high)
        end

      true ->
        binary_search(target, low, mid - 1)
    end
  end

  defp out_of_range_error(year) do
    Calendrical.IslamicYearOutOfRangeError.exception(
      year: year,
      min_year: @min_year,
      max_year: @max_year
    )
  end
end
