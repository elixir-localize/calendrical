defmodule Calendrical.Bangla do
  @moduledoc """
  The Bangla calendar of Bangladesh, each of its revisions in its own
  time: a composite of `Calendrical.Bangla.Revised1987` and
  `Calendrical.Bangla.Revised2019`.

  Both revisions begin the year on 1 Boishakh, 14 April, and number it
  as the Gregorian year it begins in less 593; they differ in Ashwin
  and Falgun. The 2019 revision took effect on 16 October 2019, 31
  Ashwin 1426 in its rules, the first day on which the two disagree,
  so the change splices the two at that day with no day lost or
  repeated. Before it a date is the 1987 revision's, from it the 2019
  revision's.

  ## Transitions

  * **(base)** — `Calendrical.Bangla.Revised1987`.

  * **2019-10-16** — `Calendrical.Bangla.Revised2019`.

  Month names are CLDR's for the Indian national calendar, whose
  months are the same months begun one earlier, at Choitro.

  ### Examples

      iex> Date.convert!(~D[2018-12-16], Calendrical.Bangla)
      ~D[1425-09-02 Calendrical.Bangla]

      iex> Date.convert!(~D[2019-12-16], Calendrical.Bangla)
      ~D[1426-09-01 Calendrical.Bangla]

      iex> Date.shift(~D[1426-06-30 Calendrical.Bangla], day: 1)
      ~D[1426-06-31 Calendrical.Bangla]

  > *"Victory Day fell on 2 Poush until the 2019 revision, and on 1
  > Poush since."*

  ### Reference

  * [Bangladeshi national calendar](https://en.wikipedia.org/wiki/Bangladeshi_national_calendar).

  """

  use Calendrical.Composite,
    calendars: [
      # 16 October 2019, the day the 2019 revision took effect
      ~D[1426-06-31 Calendrical.Bangla.Revised2019]
    ],
    base_calendar: Calendrical.Bangla.Revised1987
end
