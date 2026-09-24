defmodule Mix.Tasks.Calendrical.UmmAlQura.Verify do
  @shortdoc "Verifies the embedded Umm al-Qura reference data"

  @moduledoc """
  Verifies the Umm al-Qura reference tables embedded in Calendrical and,
  optionally, compares them with an external reference.

  `Calendrical.Islamic.UmmAlQura` is a tabular calendar: it converts dates
  using the month-start tables compiled into
  `Calendrical.Islamic.UmmAlQura.ReferenceData`. This task audits those
  tables. It never modifies them.

  For each embedded dataset (van Gent and Akmal) it checks that:

  * every month is 29 or 30 days long.

  * every year is 354 or 355 days long.

  * the months run contiguously, with no gaps or repeats.

  It then compares the two datasets with each other, and checks that
  `Calendrical.Islamic.UmmAlQura` agrees with the van Gent dataset it is
  built from.

  ## Usage

      mix calendrical.umm_al_qura.verify
      mix calendrical.umm_al_qura.verify --against reference.txt
      mix calendrical.umm_al_qura.verify --against reference.txt --dataset akmal

  ## Options

  * `--against PATH` also checks the external reference in `PATH` and
    compares it with an embedded dataset.

  * `--dataset NAME` selects the embedded dataset compared with
    `--against`: `van_gent` (the default, which the calendar uses) or
    `akmal`.

  ## Reference file format

  One month per line: the Hijri year, the Hijri month and the Gregorian
  date of the first day of that month, separated by whitespace. Blank
  lines and lines starting with `#` are ignored.

      # year month first_day
      1446 9 2025-03-01
      1446 10 2025-03-30

  Any source can be converted to this format, for example the official
  KACST tables or the `MONTH_STARTS` data of the `hijridate` Python
  package.

  ## Exit status

  The task fails if any dataset breaks one of the checks above, if the
  calendar disagrees with its data, or if the external reference gives a
  different first day for any month that both it and the embedded dataset
  cover. Differences between the two embedded datasets, and months covered
  by only one side of a comparison, are reported but do not fail the task.

  """

  use Mix.Task

  alias Calendrical.Islamic.UmmAlQura
  alias Calendrical.Islamic.UmmAlQura.ReferenceData

  @requirements ["app.config"]

  @switches [against: :string, dataset: :string]
  @datasets %{"van_gent" => :van_gent, "akmal" => :akmal}

  @impl Mix.Task
  def run(args) do
    {options, _arguments} = OptionParser.parse!(args, strict: @switches)
    dataset = dataset_option(Keyword.get(options, :dataset, "van_gent"))
    embedded = %{van_gent: embedded_months(:van_gent), akmal: embedded_months(:akmal)}

    failures =
      report_embedded(embedded) +
        report_datasets_compared(embedded) +
        report_calendar(embedded.van_gent) +
        report_against(Keyword.get(options, :against), Map.fetch!(embedded, dataset), dataset)

    if failures > 0 do
      Mix.raise("Umm al-Qura verification failed with #{failures} problem(s)")
    end

    Mix.shell().info("\nUmm al-Qura verification passed")
  end

  defp dataset_option(name) do
    case Map.fetch(@datasets, name) do
      {:ok, dataset} -> dataset
      :error -> Mix.raise("Unknown --dataset #{inspect(name)}, expected van_gent or akmal")
    end
  end

  # The last value of each embedded table is a sentinel marking the start
  # of the month after the final one, so it bounds that month's length and
  # is then dropped.
  defp embedded_months(dataset) do
    dataset
    |> dataset_data()
    |> ReferenceData.umm_al_qura_dates()
    |> Enum.map(&{&1.hijri_year, &1.hijri_month, &1.gregorian})
    |> with_lengths()
    |> Enum.drop(-1)
  end

  defp dataset_data(:van_gent), do: ReferenceData.van_gent_data()
  defp dataset_data(:akmal), do: ReferenceData.akmal_data()

  # A month's length is only known when the next month in the list is the
  # one that immediately follows it.
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

  defp following({year, 12}), do: {year + 1, 1}
  defp following({year, month}), do: {year, month + 1}

  # ── Reports ─────────────────────────────────────────────────────────────
  # Each report prints its findings and returns the number of failures.

  defp report_embedded(embedded) do
    Mix.shell().info("Embedded datasets")

    embedded
    |> Enum.sort()
    |> Enum.map(fn {name, months} -> report_problems("  #{name}", months) end)
    |> Enum.sum()
  end

  defp report_datasets_compared(%{van_gent: van_gent, akmal: akmal}) do
    differences = differences(van_gent, akmal)

    Mix.shell().info(
      "\nvan_gent compared with akmal: #{count_months(length(differences))} differ " <>
        "(expected, see Calendrical.Islamic.UmmAlQura.ReferenceData)"
    )

    Enum.each(differences, fn {key, van_gent_day, akmal_day} ->
      Mix.shell().info("  #{label(key)}: van_gent #{van_gent_day}, akmal #{akmal_day}")
    end)

    0
  end

  defp report_calendar(months) do
    problems = Enum.flat_map(months, &calendar_problems/1)
    Mix.shell().info("\n#{inspect(UmmAlQura)} compared with van_gent: #{verdict(problems)}")
    Enum.each(problems, &Mix.shell().error("  #{&1}"))
    length(problems)
  end

  defp report_against(nil, _embedded, _dataset), do: 0

  defp report_against(path, embedded, dataset) do
    reference = read_reference(path)
    failures = report_problems("\nReference #{path}", reference)
    differences = differences(embedded, reference)

    Mix.shell().info(
      "#{dataset} compared with the reference: #{count_months(length(differences))} differ"
    )

    Enum.each(differences, fn {key, embedded_day, reference_day} ->
      Mix.shell().error("  #{label(key)}: #{dataset} #{embedded_day}, reference #{reference_day}")
    end)

    report_coverage(embedded, reference, dataset)
    failures + length(differences)
  end

  defp report_problems(heading, months) do
    problems = problems(months)
    Mix.shell().info("#{heading}: #{describe(months)}, #{verdict(problems)}")
    Enum.each(problems, &Mix.shell().error("    #{&1}"))
    length(problems)
  end

  defp report_coverage(embedded, reference, dataset) do
    embedded_keys = MapSet.new(embedded, &key/1)
    reference_keys = MapSet.new(reference, &key/1)
    report_only("only in the reference", MapSet.difference(reference_keys, embedded_keys))
    report_only("only in #{dataset}", MapSet.difference(embedded_keys, reference_keys))
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

  defp calendar_problems(%{year: year, month: month, first_day: first_day, days: days} = record) do
    with {:ok, date} <- Date.new(year, month, 1, UmmAlQura),
         {:ok, ^first_day} <- Date.convert(date, Calendar.ISO),
         ^days <- UmmAlQura.days_in_month(year, month) do
      []
    else
      _other -> ["#{label(key(record))} disagrees with the calendar"]
    end
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

  # ── Formatting ──────────────────────────────────────────────────────────

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
