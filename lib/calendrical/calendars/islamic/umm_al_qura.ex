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

  Days are assumed to begin at midnight rather than at sunset.

  ## Reference

  - R.H. van Gent, "The Umm al-Qura Calendar of Saudi Arabia",
    <https://webspace.science.uu.nl/~gent0113/islam/ummalqura.htm>
  - KACST published Umm al-Qura tables.

  """

  use Calendrical.Behaviour,
    epoch: ~D[0622-07-19 Calendrical.Gregorian],
    cldr_calendar_type: :islamic_umalqura,
    months_in_ordinary_year: 12,
    months_in_leap_year: 12

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

                  cond do
                    not is_nil(next_first) -> next_first - 1
                    true -> last_first + 29
                  end
                )

  @doc """
  Returns the first Hijri year covered by the embedded Umm al-Qura
  reference data.
  """
  @spec min_year() :: pos_integer()
  def min_year, do: @min_year

  @doc """
  Returns the last Hijri year covered by the embedded Umm al-Qura
  reference data.
  """
  @spec max_year() :: pos_integer()
  def max_year, do: @max_year

  @doc """
  Returns the Gregorian `t:Date.t/0` of the first day of the given
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
  def date_to_iso_days(year, month, day) do
    case Map.fetch(@first_day_iso, {year, month}) do
      {:ok, first} -> first + day - 1
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
