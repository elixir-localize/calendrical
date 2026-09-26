defmodule Calendrical.NonGregorianFormattingTest do
  use ExUnit.Case, async: true

  describe "Localize.DateTime.Formatter — non-Gregorian calendar integration" do
    test "Hebrew date renders correct ISO week — `:calendar.iso_week_number/1` was being called on the raw Hebrew y/m/d before the fix" do
      # 5784-09-12 Hebrew = 2024-05-20 Gregorian → ISO week 21
      # of 2024. The formatter now consults the calendar's
      # `iso_week_of_year/3` callback (returns `{:error,
      # :not_defined}` for Hebrew) and falls back to
      # converting to `Calendar.ISO` before computing the
      # week.
      {:ok, d} = Date.new(5784, 9, 12, Calendrical.Hebrew)
      assert {:ok, "21"} = Localize.DateTime.Formatter.format(d, "w", :"he-IL", %{})
      assert {:ok, "2024"} = Localize.DateTime.Formatter.format(d, "Y", :"he-IL", %{})
    end

    test "Gregorian-aligned calendars use their own iso_week_of_year callback" do
      # `Calendrical.Gregorian` implements
      # `iso_week_of_year/3` properly — the formatter should
      # use the callback, not the Erlang stdlib fallback.
      {:ok, d} = Date.new(2024, 7, 1, Calendrical.Japanese)
      # Calendrical.Japanese returns {:error, :not_defined} so
      # we fall back to ISO conversion. Result still correct.
      assert {:ok, "27"} = Localize.DateTime.Formatter.format(d, "w", :"ja-JP", %{})
    end

    test "Buddhist year renders correctly with ISO week" do
      {:ok, d} = Date.new(2569, 5, 16, Calendrical.Buddhist)
      assert {:ok, "20"} = Localize.DateTime.Formatter.format(d, "w", :"th-TH", %{})
    end
  end
end
