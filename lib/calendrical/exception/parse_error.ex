defmodule Calendrical.ParseError do
  @moduledoc """
  Raised (or returned as `{:error, _}`) when `Calendrical.parse/2`
  cannot interpret an input string as a date, time, datetime, or
  date range.

  ### Fields

  * `:message` — human-readable description of the failure.

  * `:input` — the raw string that failed to parse.

  * `:locale` — the locale the parser tried.

  * `:attempts` — keyword list of `{kind, exception}` entries
    recording the sub-parser that was tried and the exception it
    returned, in the order they were attempted. The `kind` is one
    of `:interval`, `:date`, `:time`, `:datetime`.

  """

  defexception [:message, :input, :locale, :attempts]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end
end
