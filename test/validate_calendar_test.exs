defmodule Calendrical.ValidateCalendarTest do
  @moduledoc """
  What `Calendrical.validate_calendar/1` and `Calendrical.calendar_module?/1`
  take for a calendar.

  A calendar is a module that implements Elixir's `Calendar` behaviour and
  the `Calendrical` behaviour, and no more is asked: what it answers for
  each callback is its author's to keep. Each function took any module that
  exports `cldr_calendar_type/0` for one, so a module that names a CLDR
  type and implements neither behaviour was a calendar.

  The calendars are listed by hand, one of each way a calendar is made: by
  `use Calendrical.Behaviour`, by the month, the week and the Julian
  compilers, as a composite, and at runtime.

  """

  use ExUnit.Case, async: true

  alias Calendrical.Composite
  alias Calendrical.InvalidCalendarModuleError

  # Answers one of a calendar's functions, and implements neither behaviour.
  defmodule NamesAType do
    def cldr_calendar_type, do: :gregorian
  end

  @calendars [
    Calendrical.Gregorian,
    Calendrical.ISOWeek,
    Calendrical.NRF,
    Calendrical.Julian,
    Calendrical.Julian.March25,
    Calendrical.Hebrew,
    Calendrical.Chinese,
    Calendrical.Persian,
    Calendrical.Coptic,
    Calendrical.Islamic.Civil,
    Calendrical.Japanese,
    Calendrical.Reform.England
  ]

  describe "a module that implements the Calendar and Calendrical behaviours" do
    test "is a calendar, however it is made" do
      for calendar <- @calendars do
        assert Calendrical.calendar_module?(calendar), inspect(calendar)
        assert Calendrical.validate_calendar(calendar) == {:ok, calendar}
      end
    end

    test "is a calendar when it is created at runtime" do
      {:ok, fiscal} =
        Calendrical.new(Calendrical.ValidateCalendarTest.FiscalFromJuly, :month, month_of_year: 7)

      {:ok, composite} =
        Composite.new(Calendrical.ValidateCalendarTest.FromMarch1700,
          calendars: [~D[1700-03-01 Calendrical.Gregorian]]
        )

      for calendar <- [fiscal, composite] do
        assert Calendrical.calendar_module?(calendar), inspect(calendar)
        assert Calendrical.validate_calendar(calendar) == {:ok, calendar}
      end
    end
  end

  describe "Calendar.ISO" do
    test "implements Elixir's behaviour alone, and is validated as the Gregorian calendar" do
      refute Calendrical.calendar_module?(Calendar.ISO)
      assert Calendrical.validate_calendar(Calendar.ISO) == {:ok, Calendrical.Gregorian}
    end
  end

  describe "a module that implements neither behaviour" do
    test "is no calendar, though it exports a function of one" do
      assert function_exported?(NamesAType, :cldr_calendar_type, 0)

      refute Calendrical.calendar_module?(NamesAType)

      assert {:error, %InvalidCalendarModuleError{module: NamesAType}} =
               Calendrical.validate_calendar(NamesAType)
    end

    test "is no calendar" do
      for module <- [Enum, :calendar, :not_a_module, nil] do
        refute Calendrical.calendar_module?(module), inspect(module)

        assert {:error, %InvalidCalendarModuleError{module: ^module}} =
                 Calendrical.validate_calendar(module)
      end
    end

    test "is refused as a member of a composite calendar" do
      assert {:error, %InvalidCalendarModuleError{module: NamesAType}} =
               Composite.new(Calendrical.ValidateCalendarTest.OfNoCalendar,
                 calendars: [~D[1700-03-01]],
                 base_calendar: NamesAType
               )
    end
  end

  describe "what is no module" do
    test "is refused by validate_calendar/1" do
      for other <- ["Calendrical.Gregorian", 42, %{}, [Calendrical.Gregorian]] do
        assert {:error, %InvalidCalendarModuleError{}} = Calendrical.validate_calendar(other)
      end
    end
  end
end
