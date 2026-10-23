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

  # The sexagenary cycle began in a Gregorian year 4 of the cycle, so a
  # related Gregorian year is 4 ahead of its place in the cycle.
  @sexagenary_offset 4

  @typedoc "A calendar module."
  @type calendar :: module()

  # The Japanese calendar numbers years in Gregorian years while
  # its eras begin mid-year.
  @gregorian_offset_types [:japanese]

  @doc """
  Returns the year of era and era of a year of a calendar: of its first
  day, by the era calendar its `info/0` names and its year-zero rule.

  ### Arguments

  * `calendar` is a calendar module.

  * `year` is a year of the calendar.

  ### Returns

  * `{year_of_era, era}`, or `{:error, %Calendrical.InvalidDateError{}}` for a year the
    calendar does not have, or `{:error, Calendrical.MissingFieldsError.t()}`
    for no year.

  ### Examples

      iex> Calendrical.Era.year_of_era(Calendrical.Gregorian, -1)
      {2, 0}

      iex> Calendrical.Era.year_of_era(Calendrical.Julian, -1)
      {1, 0}

  """
  @spec year_of_era(calendar, Calendar.year()) ::
          {Calendar.year(), Calendar.era()} | {:error, Exception.t()}
  def year_of_era(calendar, year) when is_integer(year) do
    with %Date.Range{first: first} <- Calendrical.Period.year(calendar, year) do
      year_of_era_on(calendar, first, year)
    end
  end

  def year_of_era(calendar, year), do: missing_or_invalid(calendar, "year_of_era", year: year)

  @doc """
  Returns the year of era and era of a date of a calendar, by the era
  calendar its `info/0` names (the member's, in a composite calendar) and
  its year-zero rule. A date with no month or day is taken on the first
  day of its year.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * `{year_of_era, era}`, or `{:error, %Calendrical.InvalidDateError{}}` for a date the
    calendar does not have, or `{:error, Calendrical.MissingFieldsError.t()}`
    for no year.

  ### Examples

      iex> Calendrical.Era.year_of_era(Calendrical.Japanese, 2025, 6, 1)
      {7, 236}

      iex> Calendrical.Era.year_of_era(Calendrical.Gregorian, 2025, nil, nil)
      {2025, 1}

  """
  @spec year_of_era(calendar, Calendar.year(), Calendar.month() | nil, Calendar.day() | nil) ::
          {Calendar.year(), Calendar.era()} | {:error, Exception.t()}
  def year_of_era(calendar, year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    case Calendrical.Info.in_effect(calendar, year, month, day) do
      ^calendar -> year_of_era_in(calendar, year, month, day)
      member -> member.year_of_era(year, month, day)
    end
  end

  def year_of_era(calendar, year, month, day) when is_integer(year) do
    if is_nil(month) or is_nil(day),
      do: year_of_era(calendar, year),
      else: invalid_date(calendar, {year, month, day})
  end

  def year_of_era(calendar, year, _month, _day),
    do: missing_or_invalid(calendar, "year_of_era", year: year)

  @doc """
  Returns the day of era and era of a date of a calendar, by the era
  calendar its `info/0` names (the member's, in a composite calendar).

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * `{day_of_era, era}`, or `{:error, %Calendrical.InvalidDateError{}}` for a date the
    calendar does not have, or `{:error, Calendrical.MissingFieldsError.t()}`
    for a missing field.

  ### Examples

      iex> Calendrical.Era.day_of_era(Calendrical.Gregorian, 1, 1, 1)
      {1, 1}

      iex> Calendrical.Era.day_of_era(Calendrical.Japanese, 2019, 5, 1)
      {1, 236}

  """
  @spec day_of_era(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          {integer(), Calendar.era()} | {:error, Exception.t()}
  def day_of_era(calendar, year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    case Calendrical.Info.in_effect(calendar, year, month, day) do
      ^calendar -> day_of_era_in(calendar, year, month, day)
      member -> member.day_of_era(year, month, day)
    end
  end

  def day_of_era(calendar, year, month, day),
    do: missing_or_invalid(calendar, "day_of_era", year: year, month: month, day: day)

  @doc """
  Returns the extended year of a date: its year, numbered without a gap
  at 0 in a calendar that has no year 0, so 1 BC is 0 and 2 BC -1.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * An integer, or

  * `{:error, %Calendrical.InvalidDateError{}}` for a date the calendar does not have, or

  * `{:error, %Calendrical.MissingFieldsError{}}` for no year.

  ### Examples

      iex> Calendrical.Era.extended_year(Calendrical.Gregorian, -1, 1, 1)
      -1

      iex> Calendrical.Era.extended_year(Calendrical.Julian, -1, 1, 1)
      0

  """
  @spec extended_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          integer() | {:error, Exception.t()}
  def extended_year(calendar, year, month, day) when is_integer(year) do
    with :ok <- date_or_year(calendar, year, month, day) do
      info = Calendrical.Info.in_effect(calendar, year, month, day).info()
      if year < 0 and not info.year_zero?, do: year + 1, else: year
    end
  end

  def extended_year(calendar, year, _month, _day),
    do: missing_or_invalid(calendar, "extended_year", year: year)

  @doc """
  Returns the related Gregorian year of a date: the Gregorian year its
  calendar year begins in, as TR35 defines it, the same for every date of
  the year.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * An integer, or `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does
    not have, or `{:error, Calendrical.MissingFieldsError.t()}` for no year.

  ### Examples

      iex> Calendrical.Era.related_gregorian_year(Calendrical.Hebrew, 5786, 1, 1)
      2025

      iex> Calendrical.Era.related_gregorian_year(Calendrical.Gregorian, 2026, 6, 1)
      2026

  """
  @spec related_gregorian_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          integer() | {:error, Exception.t()}
  def related_gregorian_year(calendar, year, month, day) when is_integer(year) do
    with :ok <- date_or_year(calendar, year, month, day),
         %Date.Range{first: first} <- Calendrical.Period.year(calendar, year) do
      first |> Date.to_gregorian_days() |> Calendar.ISO.date_from_iso_days() |> elem(0)
    end
  end

  def related_gregorian_year(calendar, year, _month, _day),
    do: missing_or_invalid(calendar, "related_gregorian_year", year: year)

  @doc """
  Returns the cyclic year of a date: its place in the cycle its calendar's
  `info/0` names, reckoned as the East Asian sexagenary cycle is from the
  related Gregorian year, or its year in a calendar whose years run in no
  cycle.

  ### Arguments

  * `calendar` is a calendar module.

  * `year`, `month` and `day` are a date of the calendar.

  ### Returns

  * An integer, or `{:error, %Calendrical.InvalidDateError{}}` for a year the calendar does
    not have, or `{:error, Calendrical.MissingFieldsError.t()}` for no year.

  ### Examples

      iex> Calendrical.Era.cyclic_year(Calendrical.Chinese, 4662, 1, 1)
      42

      iex> Calendrical.Era.cyclic_year(Calendrical.Gregorian, 2026, 1, 1)
      2026

  """
  @spec cyclic_year(calendar, Calendar.year(), Calendar.month(), Calendar.day()) ::
          integer() | {:error, Exception.t()}
  def cyclic_year(calendar, year, month, day) when is_integer(year) do
    with :ok <- date_or_year(calendar, year, month, day) do
      cyclic_year_in(calendar, year, month, day)
    end
  end

  def cyclic_year(calendar, year, _month, _day),
    do: missing_or_invalid(calendar, "cyclic_year", year: year)

  defp cyclic_year_in(calendar, year, month, day) do
    case Calendrical.Info.in_effect(calendar, year, month, day).info().year_cycle do
      nil ->
        year

      cycle ->
        with related when is_integer(related) <-
               related_gregorian_year(calendar, year, month, day) do
          Integer.mod(related - @sexagenary_offset, cycle) + 1
        end
    end
  end

  # A question about a year is answered for a date the calendar has and
  # for a date with no month or day, and is a `Calendrical.InvalidDateError`
  # for a date it does not have.
  defp date_or_year(calendar, year, month, day) do
    cond do
      is_nil(month) or is_nil(day) -> :ok
      Calendrical.Month.day_in_month?(calendar, year, month, day) -> :ok
      true -> invalid_date(calendar, {year, month, day})
    end
  end

  # The year of era of a date of this calendar itself: of the date, or of
  # the first day of its month for a day the month reaches but does not
  # have, as a question that needs no day is answered.
  defp year_of_era_in(calendar, year, month, day) do
    case first_day_reached(calendar, year, month, day) do
      {:ok, date} -> year_of_era_on(calendar, date, year)
      error -> error
    end
  end

  defp day_of_era_in(calendar, year, month, day) do
    if calendar.valid_date?(year, month, day) do
      info = calendar.info()
      day_of_era(info.era_calendar_type, calendar.date_to_iso_days(year, month, day))
    else
      invalid_date(calendar, {year, month, day})
    end
  end

  # The date itself where the calendar has it, the first day of its month
  # where the month reaches the day, and an error otherwise.
  defp first_day_reached(calendar, year, month, day) do
    cond do
      calendar.valid_date?(year, month, day) ->
        {:ok, Date.new!(year, month, day, calendar)}

      Calendrical.Month.day_in_month?(calendar, year, month, day) ->
        {:ok, Calendrical.Period.month(calendar, year, month).first}

      true ->
        invalid_date(calendar, {year, month, day})
    end
  end

  # The year of era of a year on a day of it, by the era calendar and the
  # year-zero rule of the calendar in effect on that day.
  defp year_of_era_on(calendar, %Date{year: y, month: m, day: d} = date, year) do
    info = Calendrical.Info.in_effect(calendar, y, m, d).info()
    era_year(info.era_calendar_type, Date.to_gregorian_days(date), year, info.year_zero?)
  end

  # A field that is missing is a missing field; one that is no integer
  # is no date's.
  defp missing_or_invalid(calendar, function, fields) do
    if Enum.any?(fields, fn {_field, value} -> is_nil(value) end),
      do: {:error, %Calendrical.MissingFieldsError{function: function, fields: fields}},
      else: invalid_date(calendar, fields)
  end

  defp invalid_date(calendar, value) do
    {:error, Calendrical.InvalidDateError.exception(calendar: calendar, value: value)}
  end

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
    era_year(cldr_calendar_type, iso_days, year, true)
  end

  @doc """
  Returns the year of era and era number for a date, by a calendar's
  year-zero rule: `year_of_era/3` with the rule of a calendar that has a
  year 0.

  ### Arguments

  * `cldr_calendar_type` is the CLDR calendar type of the calendar, such
    as `:persian` or `:japanese`.

  * `iso_days` is the date as a count of days since the proleptic ISO
    epoch.

  * `year` is the year of the date in the calendar's own numbering.

  * `year_zero?` is whether the calendar has a year 0: where it has, year
    0 is year 1 of the era before, and where it has none, year -1 is.

  ### Returns

  * A two-tuple `{year_of_era, era}`.

  ### Examples

      iex> Calendrical.Era.era_year(:gregorian, 0, -1, true)
      {2, 0}

      iex> Calendrical.Era.era_year(:gregorian, 0, -1, false)
      {1, 0}

  """
  @spec era_year(cldr_calendar_type(), integer(), Calendar.year(), boolean()) ::
          {Calendar.year(), Calendar.era()}
  def era_year(cldr_calendar_type, iso_days, year, year_zero?) do
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
        cond do
          year >= 1 or era_data.before_era == nil -> {year, era_data.forward_era}
          year_zero? -> {1 - year, era_data.before_era}
          true -> {-year, era_data.before_era}
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

  ### Examples

      iex> era_data = Calendrical.Era.era_data(:japanese)
      iex> era_data.year_mode
      :gregorian_offset

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
