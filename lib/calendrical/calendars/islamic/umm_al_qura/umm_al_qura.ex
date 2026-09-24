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

  This module embeds the official month lengths published by KACST,
  compiled from `priv/umm_al_qura_month_lengths.csv` into one bit per
  month. Converting an Umm al-Qura date to the Gregorian calendar is an
  O(1) lookup, and the reverse a binary search over the years, with no
  floating-point arithmetic at runtime.

  ## Coverage

  The tables cover **1 AH through 1500 AH** (19 July 622 CE through
  16 November 2077 CE), the full range KACST publishes. Dates outside it
  raise `Calendrical.IslamicYearOutOfRangeError` from `date_to_iso_days/3`
  and `date_from_iso_days/1`. Run `mix calendrical.umm_al_qura.verify --kacst`
  to compare the tables with KACST's current data.

  Before 1.4.0 this calendar used R.H. van Gent's tables. Those are an
  astronomical reconstruction, reproduced by
  `Calendrical.Islamic.UmmAlQura.Astronomical`, and differ from KACST's
  official table in 695 months between 1356 and 1500 AH.

  Days begin at midnight by default. `date_at/2` maps an absolute instant to
  the Hijri date under a chosen day-start convention — midnight, an 18:00
  proxy, or true sunset (Maghrib) at Mecca.

  ## Reference

  - KACST official month lengths,
    <https://umqserv.kacst.gov.sa/api/v1/DateConversion/GetHijriMonthLengths>
  - R.H. van Gent, "The Umm al-Qura Calendar of Saudi Arabia",
    <https://webspace.science.uu.nl/~gent0113/islam/ummalqura.htm>

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-07-19 Calendrical.Gregorian],
    cldr_calendar_type: :islamic_umalqura,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12,
    first_day_of_week: 7

  @type year :: pos_integer()
  @type month :: 1..12
  @type day :: 1..30

  # The official month lengths published by KACST, one row per Hijri year
  # from 1 AH: `year,days_in_month_1,...,days_in_month_12`.
  @month_lengths_file "./priv/umm_al_qura_month_lengths.csv"
  @external_resource @month_lengths_file

  [_header | rows] =
    @month_lengths_file
    |> File.read!()
    |> String.split(~r/\r?\n/, trim: true)

  @month_lengths Enum.map(rows, fn row ->
                   [year | lengths] = row |> String.split(",") |> Enum.map(&String.to_integer/1)
                   {year, lengths}
                 end)

  # A malformed data file must fail the build rather than encode a wrong
  # month length: the years must run consecutively from 1 AH, each with
  # twelve months of 29 or 30 days.
  for {{year, lengths}, expected_year} <- Enum.with_index(@month_lengths, 1),
      year != expected_year or length(lengths) != 12 or
        not Enum.all?(lengths, &(&1 in 29..30)) do
    raise "#{@month_lengths_file}: invalid row for year #{year}: #{inspect(lengths)}"
  end

  @min_year @month_lengths |> List.first() |> elem(0)
  @max_year @month_lengths |> List.last() |> elem(0)

  # One 12-bit mask per year, Muharram in the most significant bit: 1 for a
  # 30-day month and 0 for a 29-day month.
  @year_masks @month_lengths
              |> Enum.map(fn {_year, lengths} ->
                Enum.reduce(lengths, 0, fn days, mask -> Bitwise.bsl(mask, 1) + days - 29 end)
              end)
              |> List.to_tuple()

  # The ISO day number of 1 Muharram of every year, from 1 AH (the
  # calendar's epoch) to the year after the last, so each year is bounded
  # by consecutive entries.
  @year_starts @month_lengths
               |> Enum.scan(@epoch, fn {_year, lengths}, start -> start + Enum.sum(lengths) end)
               |> then(&List.to_tuple([@epoch | &1]))

  @min_iso_days @epoch
  @max_iso_days elem(@year_starts, tuple_size(@year_starts) - 1) - 1

  # Great Mosque of Mecca (al-Masjid al-Ḥarām) — the reference location for
  # the Umm al-Qura calendar, matching Calendrical.Islamic.UmmAlQura.Astronomical.
  @mecca_location %Geo.PointZ{coordinates: {39.8262, 21.4225, 277.0}}

  # Saudi Arabia observes UTC+3 all year (no daylight saving).
  @mecca_utc_offset_seconds 3 * 60 * 60

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

    * `:sunset` — the day begins at true sunset (Maghrib) at Mecca, computed
      astronomically via `Astro`. This is upper-limb sunset, which differs by a
      minute or two from the centre-of-disk sunset that
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
    Calendrical.DayStart.date_at(
      datetime,
      __MODULE__,
      @mecca_location,
      @mecca_utc_offset_seconds,
      options
    )
  end

  @doc """
  Returns the first Hijri year covered by the embedded KACST Umm al-Qura
  tables.
  """
  # The literal bound of the shipped table; dialyzer keeps this spec
  # synchronized with the data.
  @spec min_year() :: 1
  def min_year, do: @min_year

  @doc """
  Returns the last Hijri year covered by the embedded KACST Umm al-Qura
  tables.
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
      when is_integer(hijri_year) and hijri_year in @min_year..@max_year and
             is_integer(hijri_month) and hijri_month in 1..12 do
    {:ok, Date.from_gregorian_days(first_iso_day(hijri_year, hijri_month))}
  end

  def first_day_of_month(hijri_year, hijri_month)
      when is_integer(hijri_year) and is_integer(hijri_month) and hijri_month in 1..12 do
    {:error, out_of_range_error(hijri_year)}
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
      when is_integer(year) and year in @min_year..@max_year and
             is_integer(month) and month in 1..12 and is_integer(day) do
    first_iso_day(year, month) + day - 1
  end

  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    raise out_of_range_error(year)
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
    year = year_containing(iso_days, @min_year, @max_year)
    {month, first} = month_containing(year, iso_days)
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

  defp days_in_year_lookup(year) when is_integer(year) and year in @min_year..@max_year do
    {:ok, elem(@year_starts, year) - elem(@year_starts, year - 1)}
  end

  defp days_in_year_lookup(_year), do: :error

  defp days_in_month_lookup(year, month) when is_integer(year) and year in @min_year..@max_year do
    {:ok, month_length(year, month)}
  end

  defp days_in_month_lookup(_year, _month), do: :error

  # The ISO day number of the first day of `year`/`month`: the start of the
  # year plus 29 days for every earlier month, and one more for each of
  # those that has 30 days.
  defp first_iso_day(year, month) do
    elem(@year_starts, year - 1) + 29 * (month - 1) + thirty_day_months_before(year, month)
  end

  defp month_length(year, month) do
    case thirty_days(elem(@year_masks, year - 1), month) do
      0 -> 29
      1 -> 30
    end
  end

  # Shifting out the bits of `month` and the months after it leaves one bit
  # for each earlier month.
  defp thirty_day_months_before(year, month) do
    @year_masks |> elem(year - 1) |> Bitwise.bsr(13 - month) |> count_set_bits()
  end

  defp count_set_bits(0), do: 0
  defp count_set_bits(bits), do: Bitwise.band(bits, 1) + count_set_bits(Bitwise.bsr(bits, 1))

  # 1 when `month` has 30 days in the year encoded by `mask`, otherwise 0.
  defp thirty_days(mask, month), do: Bitwise.band(Bitwise.bsr(mask, 12 - month), 1)

  # Binary search for the year whose first day is the latest one on or
  # before `iso_days`.
  defp year_containing(_iso_days, year, year), do: year

  defp year_containing(iso_days, low, high) do
    middle = div(low + high + 1, 2)

    if elem(@year_starts, middle - 1) <= iso_days,
      do: year_containing(iso_days, middle, high),
      else: year_containing(iso_days, low, middle - 1)
  end

  defp month_containing(year, iso_days) do
    month_containing(year, 1, first_iso_day(year, 1), iso_days)
  end

  defp month_containing(year, month, first, iso_days) do
    next = first + month_length(year, month)

    if month == 12 or iso_days < next,
      do: {month, first},
      else: month_containing(year, month + 1, next, iso_days)
  end

  defp out_of_range_error(year) do
    Calendrical.IslamicYearOutOfRangeError.exception(
      year: year,
      min_year: @min_year,
      max_year: @max_year
    )
  end
end
