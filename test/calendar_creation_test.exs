defmodule Calendrical.CalendarCreationTest do
  @moduledoc """
  Calendars created at runtime, by many processes at the same moment.

  A module can be defined only once, and a process that defines one
  another is defining raises. Every function that creates a calendar at
  runtime, `Calendrical.new/3`, `Calendrical.calendar_for_territory/2`,
  `Calendrical.FiscalYear.calendar_for/1`, `Calendrical.Composite.new/2`
  and `Calendrical.Reform.calendar_for/1`, creates it in the
  `Calendrical.Compiler` server, one calendar at a time: of the processes
  that create the same calendar at once, one creates it and the others
  find it there.

  The calendars' names are those the functions' documentation gives them.

  """

  use ExUnit.Case, async: true

  @processes 24

  # Runs `fun` in `@processes` processes, released at the same moment. A
  # process that raises takes the test down with it.
  defp at_once(fun) do
    gate = make_ref()

    tasks =
      for _process <- 1..@processes do
        Task.async(fn ->
          receive do
            ^gate -> fun.()
          end
        end)
      end

    Enum.each(tasks, &send(&1.pid, gate))
    Task.await_many(tasks, :timer.seconds(60))
  end

  describe "Calendrical.Composite.new/2" do
    test "creates the calendar once, and tells every other process that it exists" do
      results =
        at_once(fn ->
          Calendrical.Composite.new(Creation.Composite,
            calendars: [~D[1700-03-01 Calendrical.Gregorian]]
          )
        end)

      assert Enum.frequencies(results) == %{
               {:ok, Creation.Composite} => 1,
               {:module_already_exists, Creation.Composite} => @processes - 1
             }

      # Bound from the result, since the module exists only once the
      # test has run.
      {:ok, calendar} = Enum.find(results, &match?({:ok, _calendar}, &1))

      assert calendar.valid_date?(1700, 3, 1)
      refute calendar.valid_date?(1700, 2, 29)
    end

    # Calendars that do not make a calendar are an error for the process
    # that gave them, and the next calendar is created.
    test "answers with the error of calendars that do not make a calendar" do
      assert {:error, %Calendrical.InvalidCalendarModuleError{module: NotACalendar}} =
               Calendrical.Composite.new(Creation.NoCalendar,
                 calendars: [%{year: 1700, month: 3, day: 1, calendar: NotACalendar}]
               )

      refute Code.ensure_loaded?(Creation.NoCalendar)

      assert {:ok, Creation.AfterAnError} =
               Calendrical.Composite.new(Creation.AfterAnError,
                 calendars: [~D[1700-03-01 Calendrical.Gregorian]]
               )
    end

    test "answers for its options before it creates anything" do
      assert Calendrical.Composite.new(Creation.NoOptions, []) ==
               {:error, :no_calendars_configured}

      assert Calendrical.Composite.new(Creation.NoDates, calendars: [:nope]) ==
               {:error, :must_be_a_list_of_dates}

      assert Calendrical.Composite.new(Calendrical.Gregorian, calendars: [:nope]) ==
               {:module_already_exists, Calendrical.Gregorian}
    end
  end

  # Contents that do not compile are an error for the process that gave
  # them, and the server goes on to create the next module.
  describe "Calendrical.Compiler.create_module/3" do
    test "answers with what the contents raise, and creates the next module" do
      env = Macro.Env.location(__ENV__)

      assert {:error, %RuntimeError{message: "not compiled"}} =
               Calendrical.Compiler.create_module(
                 Creation.Uncompiled,
                 quote(do: raise("not compiled")),
                 env
               )

      refute Code.ensure_loaded?(Creation.Uncompiled)

      assert {:ok, Creation.Compiled} =
               Calendrical.Compiler.create_module(
                 Creation.Compiled,
                 quote(do: @compiled(true)),
                 env
               )
    end
  end

  describe "Calendrical.Reform.calendar_for/1" do
    test "answers every process with the territory's calendar" do
      for {territory, calendar} <- [BG: Calendrical.Reform.BG, CH: Calendrical.Reform.CH] do
        results = at_once(fn -> Calendrical.Reform.calendar_for(territory) end)

        assert Enum.uniq(results) == [{:ok, calendar}], inspect(territory)
      end
    end
  end

  describe "Calendrical.new/3" do
    test "answers every process with the calendar, of months or of weeks" do
      months = at_once(fn -> Calendrical.new(Creation.Month, :month, month_of_year: 4) end)

      assert Enum.uniq(months) == [{:ok, Creation.Month}]

      weeks =
        at_once(fn ->
          Calendrical.new(Creation.Week, :week, month_of_year: 2, weeks_in_month: [4, 4, 5])
        end)

      assert Enum.uniq(weeks) == [{:ok, Creation.Week}]
    end

    test "answers with the error of options that do not make a calendar" do
      assert {:error, _reason} = Calendrical.new(Creation.NoMonth, :month, month_of_year: 99)

      refute Code.ensure_loaded?(Creation.NoMonth)
    end
  end

  describe "a calendar of a territory" do
    test "is answered to every process" do
      territory = at_once(fn -> Calendrical.calendar_for_territory(:US) end)

      assert Enum.uniq(territory) == [{:ok, Calendrical.US}]

      fiscal = at_once(fn -> Calendrical.FiscalYear.calendar_for(:US) end)

      assert Enum.uniq(fiscal) == [{:ok, Calendrical.FiscalYear.US}]
    end
  end
end
