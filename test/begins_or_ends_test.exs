defmodule Calendrical.BeginsOrEndsTest do
  @moduledoc """
  `:begins_or_ends` names the choice `:first_or_last` makes for a calendar
  of weeks: its year begins on the first `:day_of_week` of `:month_of_year`
  or ends on the last (user, 2026-10-03). A pairing that names the other
  choice is an error, where it was accepted and ignored; left out, it
  follows `:first_or_last`. A month calendar uses neither.

  """

  use ExUnit.Case, async: true

  alias __MODULE__, as: T

  test "a calendar of weeks takes the two pairings it can keep" do
    assert {:ok, begins} =
             Calendrical.new(T.WeekBeginsFirst, :week,
               begins_or_ends: :begins,
               first_or_last: :first
             )

    assert {:ok, ends} =
             Calendrical.new(T.WeekEndsLast, :week, begins_or_ends: :ends, first_or_last: :last)

    assert %{begins_or_ends: :begins, first_or_last: :first} = begins.__config__()
    assert %{begins_or_ends: :ends, first_or_last: :last} = ends.__config__()
  end

  test "a calendar of weeks refuses the two it cannot" do
    assert Calendrical.new(T.WeekBeginsLast, :week, begins_or_ends: :begins, first_or_last: :last) ==
             {:error, ":begins_or_ends :begins needs first_or_last: :first. Found :last."}

    assert Calendrical.new(T.WeekEndsFirst, :week, begins_or_ends: :ends, first_or_last: :first) ==
             {:error, ":begins_or_ends :ends needs first_or_last: :last. Found :first."}
  end

  test "left out, it follows :first_or_last" do
    assert {:ok, last} = Calendrical.new(T.WeekLast, :week, first_or_last: :last)
    assert {:ok, first} = Calendrical.new(T.WeekDefault, :week, [])

    assert last.__config__().begins_or_ends == :ends
    assert first.__config__().begins_or_ends == :begins
    assert Calendrical.NRF.__config__().begins_or_ends == :ends
  end

  test "a month calendar uses neither" do
    assert {:ok, _calendar} =
             Calendrical.new(T.MonthEndsFirst, :month,
               begins_or_ends: :ends,
               first_or_last: :first,
               month_of_year: 7
             )
  end

  test "use Calendrical.Base.Week refuses a pairing it cannot keep" do
    assert_raise ArgumentError, ~r/:begins_or_ends :begins needs first_or_last: :first/, fn ->
      Code.compile_string("""
      defmodule Calendrical.BeginsOrEndsTest.UseBeginsLast do
        use Calendrical.Base.Week, begins_or_ends: :begins, first_or_last: :last
      end
      """)
    end
  end
end
