defmodule Calendrical.YearCache do
  @moduledoc false

  # What the calendars reckoned by astronomy work out about a year or a
  # month, kept once worked out: a Persian new year, a lunar year's new
  # year, solstices and new moons, the day an Islamic month's crescent is
  # first seen. Each takes from tens of microseconds to milliseconds of
  # astronomy, and a date's every question asks it again.
  #
  # An entry is a pure function of its key, so a value read here is the
  # value the astronomy would give, and two processes that work out the
  # same key at once store the same value. A computation that raises or
  # answers an error is not kept, so it is asked again next time.
  #
  # The table belongs to this process, a child of `Calendrical.Supervisor`.
  # Without it (Calendrical not started, as when a calendar is used while
  # compiling) every value is worked out as before. The table is cleared
  # when it reaches `@max_entries`, a few megabytes, so a sweep across
  # thousands of years cannot grow it without bound.

  use GenServer

  @table __MODULE__
  @max_entries 100_000

  @doc false
  def start_link(_options) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl GenServer
  def init(nil) do
    _table =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, nil}
  end

  @doc false
  # The value of `key`, worked out by `fun` and kept when it is not yet.
  @spec fetch(term(), (-> value)) :: value when value: term()
  def fetch(key, fun) do
    case lookup(key) do
      [{_key, value}] ->
        value

      [] ->
        value = fun.()
        store(key, value)
        value
    end
  end

  @doc false
  # As `fetch/2`, for a `fun` answering `{:ok, value}` or an error: only the
  # value of `{:ok, value}` is kept, and an error is answered as it is.
  @spec fetch_ok(term(), (-> {:ok, value} | error)) :: {:ok, value} | error
        when value: term(), error: term()
  def fetch_ok(key, fun) do
    case lookup(key) do
      [{_key, value}] ->
        {:ok, value}

      [] ->
        with {:ok, value} <- fun.() do
          store(key, value)
          {:ok, value}
        end
    end
  end

  @doc false
  # Forgets every value kept.
  @spec clear() :: :ok
  def clear do
    if table?(), do: :ets.delete_all_objects(@table)
    :ok
  end

  defp lookup(key) do
    if table?(), do: :ets.lookup(@table, key), else: []
  end

  defp store(key, value) do
    case :ets.info(@table, :size) do
      :undefined ->
        :ok

      size ->
        if size >= @max_entries, do: :ets.delete_all_objects(@table)
        :ets.insert(@table, {key, value})
        :ok
    end
  end

  defp table?, do: :ets.whereis(@table) != :undefined
end
