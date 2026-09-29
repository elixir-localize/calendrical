defmodule Calendrical.Era do
  @moduledoc """
  Era arithmetic for CLDR calendars.

  Era definitions come from the [era data in CLDR](https://github.com/unicode-org/cldr/blob/main/common/supplemental/supplementalData.xml) as Localize publishes it, where every era boundary is a proleptic Gregorian date. CLDR 49 carries the Japanese eras from Meiji onwards only; Localize supplies the earlier ones from its curated set, converted from their lunisolar proclamation dates. On first access the boundaries for a calendar type are resolved to ISO day counts and cached in `:persistent_term`, so lookups are lock-free and copy-free with no compile-time code generation.

  Two year-numbering styles cover all CLDR calendars:

  * Most calendars number their years from the epoch of their primary era, so the year of era is the calendar year itself (`{year, era}`). Years at or before zero belong to a "before" era when CLDR defines one (BCE, before ROC, before Hijra) and count backwards: year 0 is year 1 of that era.

  * The Japanese calendar numbers years in Gregorian years while eras begin mid-year, so the era is selected by the date and the year of era is counted from each era's first Gregorian year.

  A before era's days count back from its last day, as `Calendar.ISO` counts the days before the common era. A date before a calendar's first era, which TR35 gives no era, belongs to the first era counted back from its start: the year before its first is year 0, as ICU numbers the Japanese years before Taika, and the day before its first is day 0.

  """

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

      # Taika, the first Japanese era, began in 645
      iex> iso_days = Date.to_gregorian_days(~D[0600-01-01])
      iex> Calendrical.Era.year_of_era(:japanese, iso_days, 600)
      {-44, 0}

  """
  @spec year_of_era(cldr_calendar_type(), integer(), Calendar.year()) ::
          {Calendar.year(), Calendar.era()}
  def year_of_era(cldr_calendar_type, iso_days, year) do
    era_data = era_data(cldr_calendar_type)

    case era_data.year_mode do
      :gregorian_offset ->
        case find_era(era_data.records, iso_days) do
          # A lunisolar year that began before its era did is the era's
          # first year.
          {:within, record} when year < record.gregorian_year ->
            {1, record.era}

          {_position, record} ->
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

  * A two-tuple `{day_of_era, era}` where `day_of_era` counts from
    the era's first day, or back from a before era's last day. A
    date before the first era counts back from its start, so its
    `day_of_era` is 0 or less.

  ### Examples

      iex> iso_days = Date.to_gregorian_days(~D[2019-05-01])
      iex> Calendrical.Era.day_of_era(:japanese, iso_days)
      {1, 236}

      iex> iso_days = Date.to_gregorian_days(~D[1911-12-31])
      iex> Calendrical.Era.day_of_era(:roc, iso_days)
      {1, 0}

  """
  @spec day_of_era(cldr_calendar_type(), integer()) :: {integer(), Calendar.era()}
  def day_of_era(cldr_calendar_type, iso_days) do
    case find_era(era_data(cldr_calendar_type).records, iso_days) do
      {_position, %{to: to, era: era}} -> {to - iso_days + 1, era}
      {_position, %{from: from, era: era}} -> {iso_days - from + 1, era}
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
  # `iso_days`. A date before every era belongs to the era that starts
  # first, counted back from its start.
  defp find_era(records, iso_days) do
    case Enum.find(records, &holds?(&1, iso_days)) do
      nil -> {:before, first_era(records)}
      record -> {:within, record}
    end
  end

  defp holds?(%{from: from}, iso_days), do: iso_days >= from
  defp holds?(%{to: to}, iso_days), do: iso_days <= to

  defp first_era(records) do
    records
    |> Enum.filter(&is_map_key(&1, :from))
    |> Enum.min_by(& &1.from)
  end

  # The Japanese calendar numbers years in Gregorian years while
  # its eras begin mid-year.
  @gregorian_offset_types [:japanese]

  defp build_era_data(cldr_calendar_type) do
    records =
      cldr_calendar_type
      |> eras_for_calendar()
      |> Enum.reverse()
      |> Enum.map(&era_record/1)

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

  # Every era boundary is a proleptic Gregorian date. The
  # `gregorian_year` kept on each record is the year the era begins,
  # which the Japanese year-of-era arithmetic counts from.
  defp era_record([era, %{start: [year, month, day]} = span]) do
    %{
      era: era,
      from: Calendar.ISO.date_to_iso_days(year, month, day),
      gregorian_year: year,
      code: span[:code]
    }
  end

  defp era_record([era, %{end: [year, month, day]} = span]) do
    %{
      era: era,
      to: Calendar.ISO.date_to_iso_days(year, month, day),
      gregorian_year: year,
      code: span[:code]
    }
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
