defmodule Calendrical.MissingFieldsErrorTest do
  use ExUnit.Case, async: true

  describe "Calendrical.MissingFieldsError" do
    test "message with several fields" do
      error =
        Calendrical.MissingFieldsError.exception(
          function: "localize",
          fields: [year: 2026, month: nil, day: nil]
        )

      assert Exception.message(error) ==
               "localize requires at least year, month, day. Found year: 2026, month: nil, day: nil"
    end

    test "message with a single field" do
      error =
        Calendrical.MissingFieldsError.exception(
          function: "week_of_year",
          fields: [year: nil]
        )

      assert Exception.message(error) == "week_of_year requires at least year. Found year: nil"
    end

    test "raising the exception" do
      assert_raise Calendrical.MissingFieldsError,
                   "month_of_year requires at least month. Found month: nil",
                   fn ->
                     raise Calendrical.MissingFieldsError,
                       function: "month_of_year",
                       fields: [month: nil]
                   end
    end
  end

  describe "year_of_era/1 without a year" do
    # These calendars define their own year_of_era/1, whose comparison
    # guards a nil year would otherwise pass, since atoms sort after numbers.
    for calendar <- [
          Calendrical.Coptic,
          Calendrical.Ethiopic,
          Calendrical.Julian,
          Calendrical.Reform.Sweden.Transitional
        ] do
      test "#{inspect(calendar)} returns a MissingFieldsError" do
        assert {:error, %Calendrical.MissingFieldsError{fields: [year: nil]}} =
                 unquote(calendar).year_of_era(nil)
      end
    end
  end
end
