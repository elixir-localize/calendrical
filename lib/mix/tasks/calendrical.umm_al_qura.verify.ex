defmodule Mix.Tasks.Calendrical.UmmAlQura.Verify do
  @shortdoc "Verifies the embedded Umm al-Qura tables against KACST"

  @moduledoc """
  Verifies the Umm al-Qura tables embedded in Calendrical and, optionally,
  compares them with KACST's official data or another reference.

  `Calendrical.Islamic.UmmAlQura` is a tabular calendar built at compile
  time from the official month lengths published by KACST (King Abdulaziz
  City for Science and Technology), stored in
  `priv/umm_al_qura_month_lengths.csv`. This task audits the compiled
  calendar. It never modifies the data.

  It checks that:

  * every year is 354 or 355 days long.

  * every month starts the day after the previous month ends.

  * the first and last day of every month convert to the Gregorian
    calendar and back unchanged.

  ## Usage

      mix calendrical.umm_al_qura.verify
      mix calendrical.umm_al_qura.verify --kacst
      mix calendrical.umm_al_qura.verify --against reference.txt

  ## Options

  * `--kacst` downloads KACST's official month lengths and compares them
    with the embedded tables, to find out whether KACST has revised any
    month since this version of Calendrical was released.

  * `--against PATH` checks the external reference in `PATH` and compares
    it with the embedded tables.

  ## Reference file format

  One month per line: the Hijri year, the Hijri month and the Gregorian
  date of the first day of that month, separated by whitespace. Blank
  lines and lines starting with `#` are ignored.

      # year month first_day
      1446 9 2025-03-01
      1446 10 2025-03-30

  ## Exit status

  The task fails if the embedded tables break one of the checks above, or
  if KACST's data or the reference is malformed or gives a different first
  day for any month that both it and the embedded tables cover. Months
  covered by only one side are reported but do not fail the task.

  """

  use Mix.Task

  alias Calendrical.Islamic.UmmAlQura

  @requirements ["app.config"]

  @switches [against: :string, kacst: :boolean]
  @kacst_url "https://umqserv.kacst.gov.sa/api/v1/DateConversion/GetHijriMonthLengths"

  @impl Mix.Task
  def run(args) do
    {options, _arguments} = OptionParser.parse!(args, strict: @switches)
    embedded = embedded_months()

    failures =
      report_problems("Embedded tables", embedded) +
        report_calendar(embedded) +
        report_kacst(Keyword.get(options, :kacst, false), embedded) +
        report_against(Keyword.get(options, :against), embedded)

    if failures > 0 do
      Mix.raise("Umm al-Qura verification failed with #{failures} problem(s)")
    end

    Mix.shell().info("\nUmm al-Qura verification passed")
  end

  @doc false
  # Converts a KACST `GetHijriMonthLengths` response into month records,
  # anchored on the embedded calendar's first day of KACST's first year.
  # Public so the conversion can be tested without the network.
  def kacst_months(body) do
    years = kacst_years(body)
    [{first_year, _lengths} | _rest] = years
    anchor = first_day(first_year)

    {months, _next_first_day} =
      years
      |> Enum.flat_map(fn {year, lengths} ->
        lengths |> Enum.with_index(1) |> Enum.map(fn {days, month} -> {year, month, days} end)
      end)
      |> Enum.map_reduce(anchor, fn {year, month, days}, first_day ->
        {%{year: year, month: month, first_day: first_day, days: days}, Date.add(first_day, days)}
      end)

    months
  end

  defp embedded_months do
    for year <- UmmAlQura.min_year()..UmmAlQura.max_year(), month <- 1..12 do
      first_day = Date.from_gregorian_days(UmmAlQura.date_to_iso_days(year, month, 1))

      %{
        year: year,
        month: month,
        first_day: first_day,
        days: UmmAlQura.days_in_month(year, month)
      }
    end
  end

  defp first_day(year) do
    case UmmAlQura.first_day_of_month(year, 1) do
      {:ok, first_day} ->
        first_day

      {:error, _reason} ->
        Mix.raise("KACST data starts in #{year} AH, outside the embedded tables")
    end
  end

  # ── Reports ─────────────────────────────────────────────────────────────
  # Each report prints its findings and returns the number of failures.

  defp report_calendar(months) do
    problems = continuity_problems(months) ++ Enum.flat_map(months, &round_trip_problems/1)
    Mix.shell().info("\n#{inspect(UmmAlQura)} lookups: #{verdict(problems)}")
    Enum.each(problems, &Mix.shell().error("  #{&1}"))
    length(problems)
  end

  defp report_kacst(false, _embedded), do: 0

  defp report_kacst(true, embedded) do
    compare("KACST #{@kacst_url}", kacst_months(fetch_kacst()), embedded)
  end

  defp report_against(nil, _embedded), do: 0

  defp report_against(path, embedded),
    do: compare("Reference #{path}", read_reference(path), embedded)

  defp compare(heading, reference, embedded) do
    failures = report_problems("\n#{heading}", reference)
    differences = differences(embedded, reference)

    Mix.shell().info("The embedded tables differ from it in #{count_months(length(differences))}")

    Enum.each(differences, fn {key, embedded_day, reference_day} ->
      Mix.shell().error("  #{label(key)}: embedded #{embedded_day}, reference #{reference_day}")
    end)

    report_coverage(embedded, reference)
    failures + length(differences)
  end

  defp report_problems(heading, months) do
    problems = problems(months)
    Mix.shell().info("#{heading}: #{describe(months)}, #{verdict(problems)}")
    Enum.each(problems, &Mix.shell().error("    #{&1}"))
    length(problems)
  end

  defp report_coverage(embedded, reference) do
    embedded_keys = MapSet.new(embedded, &key/1)
    reference_keys = MapSet.new(reference, &key/1)
    report_only("only in the reference", MapSet.difference(reference_keys, embedded_keys))
    report_only("only in the embedded tables", MapSet.difference(embedded_keys, reference_keys))
  end

  defp report_only(description, keys) do
    if MapSet.size(keys) > 0 do
      Mix.shell().info(
        "  #{count_months(MapSet.size(keys))} #{description} " <>
          "(#{label(Enum.min(keys))} to #{label(Enum.max(keys))})"
      )
    end
  end

  # ── Checks ──────────────────────────────────────────────────────────────

  defp problems(months) do
    month_length_problems(months) ++ year_length_problems(months) ++ sequence_problems(months)
  end

  defp month_length_problems(months) do
    for %{days: days} = month <- months, is_integer(days), days not in 29..30 do
      "#{label(key(month))} is #{days} days long"
    end
  end

  # Only years whose twelve month lengths are all known can be checked.
  defp year_length_problems(months) do
    months
    |> Enum.group_by(& &1.year, & &1.days)
    |> Enum.filter(fn {_year, lengths} -> length(lengths) == 12 and nil not in lengths end)
    |> Enum.sort()
    |> Enum.flat_map(fn {year, lengths} ->
      days = Enum.sum(lengths)
      if days in 354..355, do: [], else: ["#{year} AH is #{days} days long"]
    end)
  end

  defp sequence_problems(months) do
    months
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [previous, current] ->
      if following(key(previous)) == key(current),
        do: [],
        else: ["#{label(key(current))} does not follow #{label(key(previous))}"]
    end)
  end

  defp continuity_problems(months) do
    months
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [previous, current] ->
      if Date.add(previous.first_day, previous.days) == current.first_day,
        do: [],
        else: ["#{label(key(current))} does not start the day after #{label(key(previous))} ends"]
    end)
  end

  defp round_trip_problems(%{year: year, month: month, days: days} = record) do
    Enum.flat_map([1, days], fn day ->
      with {:ok, date} <- Date.new(year, month, day, UmmAlQura),
           {:ok, gregorian} <- Date.convert(date, Calendar.ISO),
           {:ok, ^date} <- Date.convert(gregorian, UmmAlQura) do
        []
      else
        _other -> ["#{label(key(record))} day #{day} does not round-trip"]
      end
    end)
  end

  defp differences(left, right) do
    right_first_days = Map.new(right, &{key(&1), &1.first_day})

    Enum.flat_map(left, fn %{first_day: first_day} = record ->
      case Map.fetch(right_first_days, key(record)) do
        {:ok, ^first_day} -> []
        {:ok, other_first_day} -> [{key(record), first_day, other_first_day}]
        :error -> []
      end
    end)
  end

  # ── KACST ───────────────────────────────────────────────────────────────

  defp fetch_kacst do
    Enum.each([:inets, :ssl], fn application ->
      case Application.ensure_all_started(application) do
        {:ok, _started} -> :ok
        {:error, reason} -> Mix.raise("Could not start #{application}: #{inspect(reason)}")
      end
    end)

    ssl_options = [
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]
    ]

    request = {String.to_charlist(@kacst_url), []}

    case :httpc.request(:get, request, [timeout: 60_000, ssl: ssl_options], body_format: :binary) do
      {:ok, {{_version, 200, _reason}, _headers, body}} ->
        body

      {:ok, {{_version, status, _reason}, _headers, _body}} ->
        Mix.raise("KACST returned HTTP #{status}")

      {:error, reason} ->
        Mix.raise("Could not reach KACST: #{inspect(reason)}")
    end
  end

  defp kacst_years(body) do
    case decode_json(body) do
      [_first | _rest] = entries -> entries |> Enum.map(&kacst_year/1) |> Enum.sort()
      _other -> Mix.raise("KACST returned an unexpected response")
    end
  end

  defp kacst_year(%{"year" => year, "months" => lengths} = entry)
       when is_integer(year) and is_list(lengths) do
    if Enum.all?(lengths, &is_integer/1),
      do: {year, lengths},
      else: Mix.raise("KACST returned an unexpected entry: #{inspect(entry)}")
  end

  defp kacst_year(entry), do: Mix.raise("KACST returned an unexpected entry: #{inspect(entry)}")

  defp decode_json(body) do
    :json.decode(body)
  rescue
    _error -> Mix.raise("KACST returned a response that is not JSON")
  end

  # ── Reference file ──────────────────────────────────────────────────────

  defp read_reference(path) do
    case File.read(path) do
      {:ok, contents} -> parse_reference(contents, path)
      {:error, reason} -> Mix.raise("Could not read #{path}: #{:file.format_error(reason)}")
    end
  end

  defp parse_reference(contents, path) do
    months =
      contents
      |> String.split("\n")
      |> Enum.with_index(1)
      |> Enum.reject(fn {line, _number} -> blank_or_comment?(line) end)
      |> Enum.map(fn {line, number} -> parse_line(line, number, path) end)
      |> Enum.sort()

    if months == [], do: Mix.raise("#{path} contains no months")
    with_lengths(months)
  end

  defp blank_or_comment?(line) do
    trimmed = String.trim(line)
    trimmed == "" or String.starts_with?(trimmed, "#")
  end

  defp parse_line(line, number, path) do
    with [year, month, first_day] <- String.split(line),
         {year, ""} <- Integer.parse(year),
         {month, ""} when month in 1..12 <- Integer.parse(month),
         {:ok, first_day} <- Date.from_iso8601(first_day) do
      {year, month, first_day}
    else
      _other ->
        Mix.raise(
          "#{path}:#{number}: expected \"YEAR MONTH YYYY-MM-DD\", got #{inspect(String.trim(line))}"
        )
    end
  end

  # A month's length is only known when the next line is the month that
  # immediately follows it.
  defp with_lengths(months) do
    months
    |> Enum.chunk_every(2, 1)
    |> Enum.map(fn
      [{year, month, first_day}, {next_year, next_month, next_first_day}] ->
        days =
          if following({year, month}) == {next_year, next_month},
            do: Date.diff(next_first_day, first_day)

        %{year: year, month: month, first_day: first_day, days: days}

      [{year, month, first_day}] ->
        %{year: year, month: month, first_day: first_day, days: nil}
    end)
  end

  # ── Formatting ──────────────────────────────────────────────────────────

  defp following({year, 12}), do: {year + 1, 1}
  defp following({year, month}), do: {year, month + 1}

  defp key(%{year: year, month: month}), do: {year, month}

  defp label({year, month}),
    do: "#{year}/#{String.pad_leading(Integer.to_string(month), 2, "0")}"

  defp describe(months) do
    first = List.first(months)
    last = List.last(months)

    "#{count_months(length(months))}, #{label(key(first))} to #{label(key(last))} " <>
      "(#{first.first_day} to #{last_day(last)})"
  end

  defp last_day(%{first_day: first_day, days: nil}), do: first_day
  defp last_day(%{first_day: first_day, days: days}), do: Date.add(first_day, days - 1)

  defp verdict([]), do: "all checks pass"
  defp verdict(problems), do: "#{length(problems)} problem(s)"

  defp count_months(1), do: "1 month"
  defp count_months(count), do: "#{count} months"
end
