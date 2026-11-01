defmodule Calendrical.Bangla.Revised1987 do
  @moduledoc """
  The Bangla calendar of Bangladesh as the Bangla Academy revised it
  in 1987, on the reform a committee under Muhammad Shahidullah
  proposed in 1966.

  A solar calendar pinned to the Gregorian one: the year begins on 1
  Boishakh, 14 April, and is the Gregorian year it begins in less 593,
  so 1 Boishakh 1432 is 14 April 2025. The first five months have 31
  days and the rest 30, and Falgun has 31 in a leap year, one whose
  Falgun falls in a Gregorian leap year. A date therefore falls on the
  same Gregorian day every year.

  | # | Month    | Days      |
  |---|----------|-----------|
  | 1 | Boishakh | 31        |
  | 2 | Joishtho | 31        |
  | 3 | Asharh   | 31        |
  | 4 | Srabon   | 31        |
  | 5 | Bhadro   | 31        |
  | 6 | Ashwin   | 30        |
  | 7 | Kartik   | 30        |
  | 8 | Ogrohayon| 30        |
  | 9 | Poush    | 30        |
  | 10| Magh     | 30        |
  | 11| Falgun   | 30 (31)   |
  | 12| Choitro  | 30        |

  These rules held until 15 October 2019, when the 2019 revision,
  `Calendrical.Bangla.Revised2019`, took effect. `Calendrical.Bangla`
  is the calendar as Bangladesh has kept it, each revision in its own
  time. The date-holidays data writes Bangladesh's national days in
  these rules: Victory Day, 16 December, is 2 Poush.

  Month names are CLDR's for the Indian national calendar, whose
  months are the same months begun one earlier, at Choitro; days begin
  at midnight.

  ### Examples

      iex> Date.convert!(~D[2025-04-14], Calendrical.Bangla.Revised1987)
      ~D[1432-01-01 Calendrical.Bangla.Revised1987]

      iex> Date.convert!(~D[1431-09-02 Calendrical.Bangla.Revised1987], Calendar.ISO)
      ~D[2024-12-16]

  > *"Victory Day, 2 Poush 1431, is 16 December 2024."*

  ### Reference

  * Bangla Academy, *Bangla Calendar* (1987 revision).

  * [Bangladeshi national calendar](https://en.wikipedia.org/wiki/Bangladeshi_national_calendar).

  """

  use Calendrical.Calendar,
    epoch: ~D[0594-04-14 Calendrical.Gregorian],
    cldr_calendar_type: :indian,
    cldr_months: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 1],
    months_in_year: 12,
    years_in_cycle: 400

  alias Calendrical.Bangla.Rules

  @type year :: integer()
  @type month :: 1..12
  @type day :: 1..31

  @month_lengths {
    {31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30, 30},
    {31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 31, 30}
  }

  @doc """
  Returns whether a Bangla year is a leap year: whether its Falgun falls
  in a Gregorian leap year.

  ### Arguments

  * `year` is a Bangla year as an integer.

  ### Returns

  * `true` when Falgun has 31 days, otherwise `false`.

  ### Examples

      iex> Calendrical.Bangla.Revised1987.leap_year?(1430)
      true

      iex> Calendrical.Bangla.Revised1987.leap_year?(1431)
      false

  """
  @impl true
  @spec leap_year?(year()) :: boolean()
  def leap_year?(year) when is_integer(year) do
    Rules.leap_year?(year)
  end

  @doc """
  Returns the number of days in a month of a Bangla year.

  ### Arguments

  * `year` is a Bangla year as an integer.

  * `month` is a month of the year, `1..12`.

  ### Returns

  * The number of days in the month, `30..31`, or

  * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year
    does not have.

  ### Examples

      iex> Calendrical.Bangla.Revised1987.days_in_month(1430, 11)
      31

      iex> Calendrical.Bangla.Revised1987.days_in_month(1431, 11)
      30

  """
  @impl true
  @spec days_in_month(year(), month()) :: 30..31 | {:error, Exception.t()}
  def days_in_month(year, month) when is_integer(year) and month in 1..12 do
    Rules.days_in_month(@month_lengths, year, month)
  end

  def days_in_month(year, month) do
    {:error,
     Calendrical.InvalidMonthError.exception(calendar: __MODULE__, year: year, month: month)}
  end

  @doc """
  Returns the ISO day number of a Bangla date.

  ### Arguments

  * `year` is a Bangla year as an integer.

  * `month` is a month of the year, `1..12`.

  * `day` is a day of the month.

  ### Returns

  * An integer count of days since the proleptic ISO epoch.

  ### Examples

      iex> Calendrical.Bangla.Revised1987.date_to_iso_days(1432, 1, 1)
      739720

  """
  @impl true
  @spec date_to_iso_days(year(), month(), day()) :: integer()
  def date_to_iso_days(year, month, day)
      when is_integer(year) and is_integer(month) and is_integer(day) do
    Rules.date_to_iso_days(@month_lengths, year, month, day)
  end

  @doc """
  Returns the Bangla date of an ISO day number.

  ### Arguments

  * `iso_days` is an integer count of days since the proleptic ISO
    epoch.

  ### Returns

  * A `{year, month, day}` tuple.

  ### Examples

      iex> Calendrical.Bangla.Revised1987.date_from_iso_days(739_720)
      {1432, 1, 1}

  """
  @impl true
  @spec date_from_iso_days(integer()) :: {year(), month(), day()}
  def date_from_iso_days(iso_days) when is_integer(iso_days) do
    Rules.date_from_iso_days(@month_lengths, iso_days)
  end
end
