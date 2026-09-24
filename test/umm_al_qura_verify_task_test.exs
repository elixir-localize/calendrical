defmodule Mix.Tasks.Calendrical.UmmAlQura.VerifyTest do
  use ExUnit.Case, async: false

  alias Calendrical.Islamic.UmmAlQura
  alias Mix.Tasks.Calendrical.UmmAlQura.Verify

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
  end

  # Every message the task sent to the shell, as one string.
  defp output do
    receive do
      {:mix_shell, _level, [message]} -> message <> "\n" <> output()
    after
      0 -> ""
    end
  end

  # Reference lines for `years`, plus the following Muharram so the last
  # month of the range has a known length.
  defp reference_lines(years) do
    last = Enum.max(years)

    for {year, month} <- for(year <- years, month <- 1..12, do: {year, month}) ++ [{last + 1, 1}] do
      {:ok, first_day} = UmmAlQura.first_day_of_month(year, month)
      "#{year} #{month} #{first_day}"
    end
  end

  defp write_reference(tmp_dir, lines) do
    path = Path.join(tmp_dir, "reference.txt")
    File.write!(path, Enum.join(["# year month first_day" | lines], "\n"))
    path
  end

  describe "the embedded tables" do
    test "pass every check" do
      Verify.run([])

      assert output() =~
               "Embedded tables: 18000 months, 1/01 to 1500/12 (0622-07-19 to 2077-11-16), all checks pass"
    end
  end

  describe "--against" do
    @describetag :tmp_dir

    test "passes when the reference agrees with the embedded tables", %{tmp_dir: tmp_dir} do
      Verify.run(["--against", write_reference(tmp_dir, reference_lines(1445..1447))])
      assert output() =~ "The embedded tables differ from it in 0 months"
    end

    test "fails and names the month when a first day differs", %{tmp_dir: tmp_dir} do
      lines = reference_lines(1445..1447) |> List.replace_at(5, "1445 6 2000-01-01")

      assert_raise Mix.Error, ~r/verification failed/, fn ->
        Verify.run(["--against", write_reference(tmp_dir, lines)])
      end

      assert output() =~ "1445/06: embedded"
    end

    test "fails when the reference has an impossible month", %{tmp_dir: tmp_dir} do
      {:ok, first_day} = UmmAlQura.first_day_of_month(1446, 1)
      lines = ["1446 1 #{first_day}", "1446 2 #{Date.add(first_day, 28)}"]

      assert_raise Mix.Error, fn -> Verify.run(["--against", write_reference(tmp_dir, lines)]) end
      assert output() =~ "1446/01 is 28 days long"
    end

    test "reports a malformed line with its line number", %{tmp_dir: tmp_dir} do
      path = write_reference(tmp_dir, ["1446 1 not-a-date"])

      assert_raise Mix.Error, ~r/reference\.txt:2: expected/, fn ->
        Verify.run(["--against", path])
      end
    end

    test "rejects a file with no months", %{tmp_dir: tmp_dir} do
      path = write_reference(tmp_dir, [])
      assert_raise Mix.Error, ~r/contains no months/, fn -> Verify.run(["--against", path]) end
    end

    test "rejects a missing file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "missing.txt")
      assert_raise Mix.Error, ~r/Could not read/, fn -> Verify.run(["--against", path]) end
    end
  end

  describe "kacst_months/1" do
    defp kacst_json(years) do
      entries =
        for year <- years do
          lengths = Enum.map_join(1..12, ",", &UmmAlQura.days_in_month(year, &1))
          ~s({"year":#{year},"months":[#{lengths}]})
        end

      "[" <> Enum.join(entries, ",") <> "]"
    end

    test "anchors KACST's month lengths on the embedded calendar" do
      months = Verify.kacst_months(kacst_json(1446..1447))

      assert length(months) == 24

      for %{year: year, month: month, first_day: first_day} <- months do
        assert UmmAlQura.first_day_of_month(year, month) == {:ok, first_day}
      end
    end

    test "rejects a response that is not JSON" do
      assert_raise Mix.Error, ~r/not JSON/, fn -> Verify.kacst_months("<html>") end
    end

    test "rejects a response of the wrong shape" do
      assert_raise Mix.Error, ~r/unexpected response/, fn ->
        Verify.kacst_months(~s({"year":1}))
      end

      assert_raise Mix.Error, ~r/unexpected entry/, fn ->
        Verify.kacst_months(~s([{"year":1}]))
      end
    end

    test "rejects data that starts outside the embedded tables" do
      json = ~s([{"year":1501,"months":[29,30,29,30,29,30,29,30,29,30,29,30]}])
      assert_raise Mix.Error, ~r/starts in 1501 AH/, fn -> Verify.kacst_months(json) end
    end
  end

  test "rejects an unknown option" do
    assert_raise OptionParser.ParseError, fn -> Verify.run(["--dataset", "akmal"]) end
  end
end
