defmodule Calendrical.Math.Test do
  use ExUnit.Case, async: true

  test "Date.shift with month coercion" do
    assert Date.shift(~D[2024-02-29], month: 12) == ~D[2025-02-28]
    assert Date.shift(~D[2024-02-29], month: -12) == ~D[2023-02-28]
  end

  test "Date.shift with year coercion" do
    assert Date.shift(~D[2024-02-29], year: 1) == ~D[2025-02-28]
    assert Date.shift(~D[2024-02-29], year: -1) == ~D[2023-02-28]
  end
end
