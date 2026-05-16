defmodule Calendrical.TimeParseError do
  @moduledoc """
  Raised (or returned as `{:error, _}`) when
  `Calendrical.Time.parse/2` can't interpret an input string
  as a time.

  ### Fields

  * `:message` — human-readable description of the failure.

  * `:input` — the raw string that failed to parse.

  * `:locale` — the locale the parser tried.

  """

  defexception [:message, :input, :locale]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end
end
