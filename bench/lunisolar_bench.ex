defmodule Calendrical.Bench.Lunisolar do
  @moduledoc false

  # Conversion cost for the lunisolar calendars, and the astronomical work
  # behind it. Compiled in :dev only. Run with:
  #
  #     mix run -e "Calendrical.Bench.Lunisolar.run()"
  #
  # Timings are the fastest of several runs, in microseconds per date.
  # Call counts are for one conversion of 2024-06-15 each way.

  alias Calendrical.Lunisolar

  @calendars [
    Calendrical.Chinese,
    Calendrical.Korean,
    Calendrical.Vietnamese,
    Calendrical.LunarJapanese
  ]

  @counted [
    {Lunisolar, :new_year_in_sui, 2},
    {Lunisolar, :december_solstice_on_or_before, 2},
    {Lunisolar, :new_moon_before, 2},
    {Lunisolar, :new_moon_on_or_after, 2}
  ]

  @runs 3

  @spec run() :: :ok
  def run do
    days = Enum.to_list(Date.range(~D[2024-01-01], ~D[2024-12-31]))
    IO.puts("us per date, 366 consecutive days of 2024 (fastest of #{@runs})")

    for calendar <- @calendars do
      converted = Enum.map(days, &Date.convert!(&1, calendar))
      into = fastest(fn -> Enum.each(days, &Date.convert!(&1, calendar)) end)
      back = fastest(fn -> Enum.each(converted, &Date.convert!(&1, Calendar.ISO)) end)

      IO.puts(
        "  #{String.pad_trailing(inspect(calendar), 28)}" <>
          "ISO->calendar #{per_date(into, days)}  calendar->ISO #{per_date(back, days)}"
      )
    end

    IO.puts("\nCalls per conversion of 2024-06-15 (ISO->calendar / calendar->ISO)")

    for calendar <- @calendars do
      date = Date.convert!(~D[2024-06-15], calendar)
      into = call_counts(fn -> Date.convert!(~D[2024-06-15], calendar) end)
      back = call_counts(fn -> Date.convert!(date, Calendar.ISO) end)

      counts =
        Enum.map_join(@counted, "  ", fn {_module, function, _arity} = mfa ->
          "#{function} #{Map.fetch!(into, mfa)}/#{Map.fetch!(back, mfa)}"
        end)

      IO.puts("  #{String.pad_trailing(inspect(calendar), 28)}#{counts}")
    end

    :ok
  end

  defp fastest(fun) do
    fun.()
    1..@runs |> Enum.map(fn _run -> fun |> :timer.tc() |> elem(0) end) |> Enum.min()
  end

  defp per_date(microseconds, days) do
    microseconds |> div(length(days)) |> Integer.to_string() |> String.pad_leading(5)
  end

  defp call_counts(fun) do
    for mfa <- @counted, do: :erlang.trace_pattern(mfa, true, [:call_count, :local])
    :erlang.trace(self(), true, [:call])
    fun.()
    :erlang.trace(self(), false, [:call])

    counts =
      Map.new(@counted, fn mfa ->
        {:call_count, count} = :erlang.trace_info(mfa, :call_count)
        {mfa, count}
      end)

    for mfa <- @counted, do: :erlang.trace_pattern(mfa, false, [:call_count, :local])
    counts
  end
end
