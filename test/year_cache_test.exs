defmodule Calendrical.YearCacheTest do
  # The cache the calendars reckoned by astronomy keep their years in. Not
  # async: the calendars' own tests clear it.
  use ExUnit.Case, async: false

  alias Calendrical.YearCache

  setup do
    key = {__MODULE__, make_ref()}
    %{key: key}
  end

  test "a value is worked out once and kept", %{key: key} do
    assert YearCache.fetch(key, fn -> worked_out(42) end) == 42
    assert YearCache.fetch(key, fn -> worked_out(0) end) == 42
    assert_received :worked_out
    refute_received :worked_out
  end

  test "an {:ok, value} is kept and an error is not", %{key: key} do
    error = {:error, %Calendrical.UnsupportedDateRangeError{value: 1, range: 1..2}}
    assert YearCache.fetch_ok(key, fn -> error end) == error
    assert YearCache.fetch_ok(key, fn -> {:ok, 7} end) == {:ok, 7}
    assert YearCache.fetch_ok(key, fn -> {:ok, 8} end) == {:ok, 7}
  end

  test "a computation that raises keeps nothing", %{key: key} do
    assert_raise ArgumentError, fn -> YearCache.fetch(key, fn -> raise ArgumentError end) end
    assert YearCache.fetch(key, fn -> :worked_out end) == :worked_out
  end

  defp worked_out(value) do
    send(self(), :worked_out)
    value
  end

  test "clear/0 forgets every value", %{key: key} do
    assert YearCache.fetch(key, fn -> 1 end) == 1
    assert YearCache.clear() == :ok
    assert YearCache.fetch(key, fn -> 2 end) == 2
  end
end
