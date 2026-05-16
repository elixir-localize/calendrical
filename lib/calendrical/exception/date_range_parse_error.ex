defmodule Calendrical.DateRangeParseError do
  @moduledoc """
  Raised (or returned as `{:error, _}`) by
  `Calendrical.Date.parse_range/2` when the input can't be
  interpreted as a date range, or when both endpoints parsed
  successfully but the resulting range is invalid (e.g.
  inverted when `:allow_inverted` is `false`).

  ### Fields

  * `:message` — human-readable description of the failure.

  * `:input` — the raw input (string or `{from, to}` tuple).

  * `:reason` — atom describing the failure category:
    `:no_separator`, `:inverted`, `:from_parse_failed`,
    `:to_parse_failed`.

  * `:cause` — when the failure is from a sub-parse, the
    underlying `Calendrical.DateParseError`.

  """

  defexception [:message, :input, :reason, :cause]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end
end
