defmodule Calendrical.Era do
  @moduledoc """
  Era arithmetic for CLDR calendars.

  Era definitions come from the [era data in CLDR](https://github.com/unicode-org/cldr/blob/main/common/supplemental/supplementalData.xml),
  where era boundaries are expressed as proleptic Gregorian dates —
  with one exception: Japanese eras before Meiji are lunisolar
  passthroughs (the proclamation's traditional `年月日` numerals
  copied into the Western fields unconverted) and are resolved
  through `Calendrical.LunarJapanese`. On first access the
  boundaries for a calendar type are resolved to ISO day counts and
  cached in `:persistent_term`, so lookups are lock-free and
  copy-free with no compile-time code generation.

  Two year-numbering styles cover all CLDR calendars:

  * Most calendars number their years from the epoch of their
    primary era, so the year of era is the calendar year itself
    (`{year, era}`). Years at or before zero belong to a
    "before" era when CLDR defines one (BCE, before ROC, before
    Hijra) and count backwards: year 0 is year 1 of that era.

  * The Japanese calendar numbers years in Gregorian years while
    eras begin mid-year, so the era is selected by the date and
    the year of era is counted from each era's first Gregorian
    year.

  """

  require Logger

  @typedoc "A CLDR calendar type, such as `:gregorian` or `:persian`."
  @type cldr_calendar_type :: atom()

  @doc """
  Returns the year of era and era number for a date.

  ### Arguments

  * `cldr_calendar_type` is the CLDR calendar type of the
    calendar, such as `:persian` or `:japanese`.

  * `iso_days` is the date as a count of days since the
    proleptic ISO epoch.

  * `year` is the year of the date in the calendar's own
    numbering.

  ### Returns

  * A two-tuple `{year_of_era, era}`.

  ### Examples

      iex> iso_days = Date.to_gregorian_days(~D[2019-05-01])
      iex> Calendrical.Era.year_of_era(:japanese, iso_days, 2019)
      {1, 236}

      iex> Calendrical.Era.year_of_era(:persian, 0, 1405)
      {1405, 0}

  """
  @spec year_of_era(cldr_calendar_type(), integer(), Calendar.year()) ::
          {Calendar.year(), Calendar.era()}
  def year_of_era(cldr_calendar_type, iso_days, year) do
    era_data = era_data(cldr_calendar_type)

    case era_data.year_mode do
      :gregorian_offset ->
        record = find_era(era_data.records, iso_days, cldr_calendar_type)

        if year < record.gregorian_year do
          {1, record.era}
        else
          {year - record.gregorian_year + 1, record.era}
        end

      :identity ->
        if year >= 1 or era_data.before_era == nil do
          {year, era_data.forward_era}
        else
          {1 - year, era_data.before_era}
        end
    end
  end

  @doc """
  Returns the day of era and era number for a date.

  ### Arguments

  * `cldr_calendar_type` is the CLDR calendar type of the
    calendar, such as `:persian` or `:japanese`.

  * `iso_days` is the date as a count of days since the
    proleptic ISO epoch.

  ### Returns

  * A two-tuple `{day_of_era, era}` where `day_of_era` is the
    count of days since the era began.

  ### Examples

      iex> iso_days = Date.to_gregorian_days(~D[2019-05-01])
      iex> Calendrical.Era.day_of_era(:japanese, iso_days)
      {1, 236}

  """
  @spec day_of_era(cldr_calendar_type(), integer()) :: {Calendar.day(), Calendar.era()}
  def day_of_era(cldr_calendar_type, iso_days) do
    record = find_era(era_data(cldr_calendar_type).records, iso_days, cldr_calendar_type)

    case record do
      %{from: from} when is_integer(from) -> {iso_days - from + 1, record.era}
      %{to: _to} -> {iso_days + 1, record.era}
    end
  end

  @doc """
  Returns the resolved era data for a CLDR calendar type.

  The data is computed on first access and cached in
  `:persistent_term`.

  ### Arguments

  * `cldr_calendar_type` is the CLDR calendar type of the
    calendar, such as `:persian` or `:japanese`.

  ### Returns

  * A map with the era records (most recent era first), the
    year-numbering mode and the forward/before era numbers.

  """
  @spec era_data(cldr_calendar_type()) :: map()
  def era_data(cldr_calendar_type) when is_atom(cldr_calendar_type) do
    key = {__MODULE__, cldr_calendar_type}

    case :persistent_term.get(key, :__not_loaded__) do
      :__not_loaded__ ->
        value = build_era_data(cldr_calendar_type)
        :persistent_term.put(key, value)
        value

      value ->
        value
    end
  end

  # Scan the records (most recent first) for the era containing
  # `iso_days`, mirroring the clause ordering of the previous
  # generated-module implementation.
  defp find_era(records, iso_days, cldr_calendar_type) do
    Enum.find(records, fn
      %{from: from} when is_integer(from) -> iso_days >= from
      %{to: to} when is_integer(to) -> iso_days <= to
    end) ||
      raise ArgumentError,
            "date with iso days #{inspect(iso_days)} is before all eras " <>
              "of the #{inspect(cldr_calendar_type)} calendar"
  end

  # The Japanese calendar numbers years in Gregorian years while
  # its eras begin mid-year.
  @gregorian_offset_types [:japanese]

  # Japanese eras before Meiji (era index 232) are recorded in CLDR
  # as lunisolar passthroughs: the proclamation's traditional
  # `年月日` numerals copied into the Western fields with no
  # calendar conversion. Meiji onwards the dates are true proleptic
  # Gregorian, fixed by government proclamation. See the validation
  # research in the localize repository, plans/japanese_eras.md.
  @first_gregorian_japanese_era 232

  # `Calendrical.LunarJapanese` year 1 corresponds to 645 CE, so a
  # CLDR raw year converts to a lunisolar year by subtracting 644.
  @lunar_japanese_year_offset 644

  defp build_era_data(cldr_calendar_type) do
    records =
      cldr_calendar_type
      |> eras_for_calendar()
      |> Enum.reverse()
      |> Enum.map(&era_record(&1, cldr_calendar_type))

    year_mode =
      if cldr_calendar_type in @gregorian_offset_types, do: :gregorian_offset, else: :identity

    forward_era =
      Enum.find_value(records, fn
        %{from: from, era: era} when is_integer(from) -> era
        _other -> nil
      end)

    before_era =
      Enum.find_value(records, fn
        %{to: to, era: era} when is_integer(to) -> era
        _other -> nil
      end)

    %{
      cldr_calendar_type: cldr_calendar_type,
      year_mode: year_mode,
      records: records,
      forward_era: forward_era,
      before_era: before_era
    }
  end

  # CLDR era boundaries are proleptic Gregorian dates for every
  # calendar type except the pre-Meiji Japanese eras, which are
  # handled in `start_iso_days/4` below. The `gregorian_year` kept
  # on each record is the raw CLDR year label, which is what the
  # Japanese year-of-era arithmetic counts from.
  defp era_record([era, %{start: [year, _month, _day] = date} = span], cldr_calendar_type) do
    %{
      era: era,
      from: start_iso_days(era, date, span, cldr_calendar_type),
      gregorian_year: year,
      code: span[:code]
    }
  end

  defp era_record([era, %{end: [year, month, day]} = span], _cldr_calendar_type) do
    %{
      era: era,
      to: Calendar.ISO.date_to_iso_days(year, month, day),
      gregorian_year: year,
      code: span[:code]
    }
  end

  # Pre-Meiji Japanese era dates are lunisolar passthroughs, so the
  # boundary is resolved by converting the traditional lunisolar
  # date. Curated entries (identified by a `:lunisolar` provenance
  # field, per the japanese_eras plan) already carry a proleptic
  # Gregorian `:start` and are used directly.
  defp start_iso_days(era, [year, month, day], span, :japanese)
       when era < @first_gregorian_japanese_era do
    if Map.has_key?(span, :lunisolar) do
      Calendar.ISO.date_to_iso_days(year, month, day)
    else
      lunar_year = year - @lunar_japanese_year_offset

      case Calendrical.LunarJapanese.new(lunar_year, month, day) do
        {:ok, date} ->
          date |> Date.convert!(Calendar.ISO) |> Date.to_gregorian_days()

        {:error, _reason} when day == 30 ->
          # The historical 宣明暦-family calendars sometimes recorded
          # a 30th day where the astronomical reconstruction gives
          # the month 29 days (era 187 永正 [1504, 2, 30]). The
          # proclamation day is then the day after the reconstructed
          # month's last day (confirmed against the wiki-canonical
          # 1504-03-26 in japanese_eras_research.json).
          case Calendrical.LunarJapanese.new(lunar_year, month, 29) do
            {:ok, date} ->
              iso_days = date |> Date.convert!(Calendar.ISO) |> Date.to_gregorian_days()
              iso_days + 1

            {:error, reason} ->
              gregorian_fallback(era, [year, month, day], reason)
          end

        {:error, reason} ->
          gregorian_fallback(era, [year, month, day], reason)
      end
    end
  end

  defp start_iso_days(_era, [year, month, day], _span, _cldr_calendar_type) do
    Calendar.ISO.date_to_iso_days(year, month, day)
  end

  # Safety net: no CLDR row is currently known to hit this (era 115
  # 建保 [1213, 12, 6] used to, before the lunisolar leap-year
  # detection was fixed). Should a row ever fail to resolve
  # astronomically, fall back to the raw Gregorian reading — with the
  # day clamped to a valid ISO day — rather than failing every
  # Japanese era lookup. Curated data with a `:lunisolar` provenance
  # field supersedes this fallback.
  defp gregorian_fallback(era, [year, month, day], reason) do
    Logger.warning(
      "[Calendrical] Japanese era #{era} start #{inspect([year, month, day])} " <>
        "could not be resolved as a lunisolar date (#{inspect(reason)}); " <>
        "using the raw Gregorian reading"
    )

    day = min(day, Calendar.ISO.days_in_month(year, month))
    Calendar.ISO.date_to_iso_days(year, month, day)
  end

  defp eras_for_calendar(cldr_calendar_type) do
    case Map.fetch(Localize.SupplementalData.calendars(), cldr_calendar_type) do
      {:ok, %{eras: eras}} ->
        eras

      _other ->
        raise ArgumentError,
              "unknown CLDR calendar type #{inspect(cldr_calendar_type)}. " <>
                "Known types are #{inspect(Map.keys(Localize.SupplementalData.calendars()))}"
    end
  end
end
