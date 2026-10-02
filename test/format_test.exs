defmodule Calendrical.Format.Test do
  use ExUnit.Case
  doctest Calendrical.Format

  setup do
    month =
      Calendrical.Format.month(2019, 4,
        formatter: Calendrical.Test.Formatter,
        caption: "My Caption",
        calendar: Calendrical.Gregorian,
        private: "My private options"
      )

    gregorian =
      Calendrical.Format.year(2019,
        formatter: Calendrical.Test.Formatter,
        caption: "My Caption",
        calendar: Calendrical.Gregorian,
        private: "My private options"
      )

    nrf =
      Calendrical.Format.year(2019,
        formatter: Calendrical.Test.Formatter,
        caption: "My Caption",
        calendar: Calendrical.NRF,
        private: "My private options"
      )

    {:ok, month: month, gregorian: gregorian, nrf: nrf}
  end

  test "that we return a month, weeks, and days", context do
    formatted = context[:month]
    assert formatted[:year] == 2019
    assert formatted[:month] == 4
    assert length(formatted[:weeks]) == 6
    assert hd(formatted[:weeks])[:week_number] == 14
  end

  test "pass private options through", context do
    formatted = context[:month]
    assert formatted[:options].private == "My private options"
  end

  test "we have 12 months and a caption", context do
    gregorian = context[:gregorian]

    assert length(gregorian[:months]) == 12
    assert gregorian[:options].caption == "My Caption"
  end

  test "that day names are calendar correct", context do
    gregorian = context[:gregorian]
    nrf = context[:nrf]

    assert gregorian[:options].day_names ==
             [
               {1, "Mon"},
               {2, "Tue"},
               {3, "Wed"},
               {4, "Thu"},
               {5, "Fri"},
               {6, "Sat"},
               {7, "Sun"}
             ]

    assert nrf[:options].day_names ==
             [
               {1, "Sun"},
               {2, "Mon"},
               {3, "Tue"},
               {4, "Wed"},
               {5, "Thu"},
               {6, "Fri"},
               {7, "Sat"}
             ]
  end

  test "Weeks that don't start on Monday" do
    defmodule MyApp.Calendar.US do
      @moduledoc """
      This is the same as a gregorian calendar, but with Sunday starting the week.
      """

      use Calendrical.Base.Month, day_of_week: Calendrical.sunday()
    end

    options = [
      formatter: Calendrical.Test.Formatter,
      caption: "My Caption",
      calendar: MyApp.Calendar.US
    ]

    first_day =
      Calendrical.Format.month(2020, 3, options)
      |> Map.get(:weeks)
      |> hd
      |> Map.get(:days)
      |> hd
      |> Calendrical.day_of_week(:monday)

    assert first_day == 7
  end

  test "a month opening in a short calendar week still lays out whole weeks" do
    # 1 Tishri 5787 is a Saturday, alone in its year's week 1
    weeks =
      Calendrical.Format.month(5787, 1,
        formatter: Calendrical.Test.Formatter,
        calendar: Calendrical.Hebrew
      )
      |> Map.get(:weeks)

    assert Enum.all?(weeks, &(length(&1.days) == 7))
    assert List.last(hd(weeks).days) == ~D[5787-01-01 Calendrical.Hebrew]

    weeks
    |> Enum.flat_map(& &1.days)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.each(fn [day, next] -> assert Date.diff(next, day) == 1 end)
  end

  # A calendar of weeks' month is the weeks its pattern gives it. ISO weeks
  # are laid out 4-5-4 through each quarter, and the last month takes the
  # 53rd week of a long year: 2026 has 53 ISO weeks and 2025 has 52.
  test "a calendar of weeks' month is laid out as the weeks of its pattern" do
    assert :calendar.iso_week_number({2026, 12, 31}) == {2026, 53}
    assert :calendar.iso_week_number({2025, 12, 28}) == {2025, 52}

    for {year, month, first_week, weeks} <- [
          {2026, 1, 1, 4},
          {2026, 2, 5, 5},
          {2026, 3, 10, 4},
          {2026, 12, 49, 5},
          {2025, 12, 49, 4}
        ] do
      formatted =
        Calendrical.Format.month(year, month,
          formatter: Calendrical.Test.Formatter,
          calendar: Calendrical.ISOWeek
        )

      assert length(formatted[:weeks]) == weeks, "#{year} month #{month}"
      assert hd(formatted[:weeks])[:week_number] == first_week, "#{year} month #{month}"
      assert Enum.all?(formatted[:weeks], &(length(&1.days) == 7))
    end
  end

  test "Setting the :day_names option" do
    day_names = [
      {1, "One"},
      {2, "Two"},
      {3, "Three"},
      {4, "Four"},
      {5, "Five"},
      {6, "Six"},
      {7, "Seven"}
    ]

    formatter = Calendrical.Formatter.Markdown

    assert Calendrical.Format.month(2019, 1, formatter: formatter, day_names: day_names) =~
             ~r"### January 2019\n\nOne | Two | Three | Four | Five | Six | Seven\n.*"
  end
end
