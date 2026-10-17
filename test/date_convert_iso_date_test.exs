defmodule Calendrical.DateConvert.Test do
  use ExUnit.Case, async: true

  test "that {2019, 1, 1} converts to {2018, 12, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.date_from_iso_days(Date.to_gregorian_days(~D[2019-01-01])) ==
             {2018, 12, 1}
  end

  test "that {2019, 2, 1} converts to {2019, 1, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.date_from_iso_days(Date.to_gregorian_days(~D[2019-02-01])) ==
             {2019, 1, 1}
  end

  test "that {2019, 3, 1} converts to {2019, 2, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.date_from_iso_days(Date.to_gregorian_days(~D[2019-03-01])) ==
             {2019, 2, 1}
  end

  test "that {2019, 4, 1} converts to {2019, 3, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.date_from_iso_days(Date.to_gregorian_days(~D[2019-04-01])) ==
             {2019, 3, 1}
  end

  test "that {2019, 12, 1} converts to {2019, 11, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.date_from_iso_days(Date.to_gregorian_days(~D[2019-12-01])) ==
             {2019, 11, 1}
  end

  test "that {2018, 12, 1} re-converts to {2019, 1, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.base_date(2018, 12, 1) == {2019, 1, 1}
  end

  test "that {2019, 1, 1} re-converts to {2019, 2, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.base_date(2019, 1, 1) == {2019, 2, 1}
  end

  test "that {2019, 2, 1} re-converts to {2019, 3, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.base_date(2019, 2, 1) == {2019, 3, 1}
  end

  test "that {2019, 3, 1} re-converts to {2019, 4, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.base_date(2019, 3, 1) == {2019, 4, 1}
  end

  test "that {2019, 11, 1} re-converts to {2019, 12, 1} for month-based calendar starting in Feb " do
    assert Calendrical.Range.Feb.base_date(2019, 11, 1) == {2019, 12, 1}
  end
end
