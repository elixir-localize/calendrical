defmodule Calendrical.Bangla.Revised2019 do
  @moduledoc """
  The Bangla calendar of Bangladesh as the Bangla Academy revised it
  in 2019, in force from 16 October 2019.

  The 2019 revision keeps the 1987 one's year, begun on 1 Boishakh, 14
  April, and numbered as the Gregorian year it begins in less 593, and
  moves a day from Falgun to Ashwin so that the national days fall on
  the Bengali dates of the events they mark: 21 February is 8 Falgun,
  26 March 12 Choitro and 16 December 1 Poush. The first six months
  have 31 days, Falgun 29, or 30 in a leap year, one whose Falgun falls
  in a Gregorian leap year, and the rest 30.

  | # | Month    | Days      |
  |---|----------|-----------|
  | 1 | Boishakh | 31        |
  | 2 | Joishtho | 31        |
  | 3 | Asharh   | 31        |
  | 4 | Srabon   | 31        |
  | 5 | Bhadro   | 31        |
  | 6 | Ashwin   | 31        |
  | 7 | Kartik   | 30        |
  | 8 | Ogrohayon| 30        |
  | 9 | Poush    | 30        |
  | 10| Magh     | 30        |
  | 11| Falgun   | 29 (30)   |
  | 12| Choitro  | 30        |

  The rules before it are `Calendrical.Bangla.Revised1987`, and
  `Calendrical.Bangla` is the calendar as Bangladesh has kept it, each
  revision in its own time. The two agree on every day of a year up to
  30 Ashwin, so 16 October 2019, the day the revision took effect, is
  31 Ashwin 1426 in these rules and 1 Kartik in the earlier ones.

  Month names are CLDR's for the Indian national calendar, whose
  months are the same months begun one earlier, at Choitro; days begin
  at midnight. The era is
  the Bangla era, which CLDR does not name: "BS" and "Bangabda" in
  English and বঙ্গাব্দ in Bengali, from Calendrical's own catalog
  (`era_names/1`).

  ### Examples

      iex> Date.convert!(~D[2025-12-16], Calendrical.Bangla.Revised2019)
      ~D[1432-09-01 Calendrical.Bangla.Revised2019]

      iex> Date.convert!(~D[1430-11-08 Calendrical.Bangla.Revised2019], Calendar.ISO)
      ~D[2024-02-21]

  > *"Victory Day, 16 December 2025, is 1 Poush 1432."*

  ### Reference

  * Bangla Academy, *Bangla Calendar* (2019 revision).

  * [Bangladeshi national calendar](https://en.wikipedia.org/wiki/Bangladeshi_national_calendar).

  """

  use Calendrical.Calendar,
    epoch: ~D[0594-04-14 Calendrical.Gregorian],
    cldr_calendar_type: :indian,
    cldr_months: [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 1],
    era_names: %{0 => [wide: "Bangabda", abbreviated: "BS", narrow: "BS"]},
    months_in_year: 12,
    years_in_cycle: 400

  alias Calendrical.Bangla.Rules

  @type year :: integer()
  @type month :: 1..12
  @type day :: 1..31

  @month_lengths {
    {31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 29, 30},
    {31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30}
  }

  @doc """
  Returns whether a Bangla year is a leap year: whether its Falgun falls
  in a Gregorian leap year.

  ### Arguments

  * `year` is a Bangla year as an integer.

  ### Returns

  * `true` when Falgun has 30 days, otherwise `false`.

  ### Examples

      iex> Calendrical.Bangla.Revised2019.leap_year?(1430)
      true

      iex> Calendrical.Bangla.Revised2019.leap_year?(1431)
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

  * The number of days in the month, `29..31`, or

  * `{:error, %Calendrical.InvalidMonthError{}}` for a month the year
    does not have.

  ### Examples

      iex> Calendrical.Bangla.Revised2019.days_in_month(1430, 11)
      30

      iex> Calendrical.Bangla.Revised2019.days_in_month(1431, 11)
      29

  """
  @impl true
  @spec days_in_month(year(), month()) :: 29..31 | {:error, Exception.t()}
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

      iex> Calendrical.Bangla.Revised2019.date_to_iso_days(1432, 1, 1)
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

      iex> Calendrical.Bangla.Revised2019.date_from_iso_days(739_720)
      {1432, 1, 1}

  """
  @impl true
  @spec date_from_iso_days(integer()) :: {year(), month(), day()}
  def date_from_iso_days(iso_days) when is_integer(iso_days) do
    Rules.date_from_iso_days(@month_lengths, iso_days)
  end
end
