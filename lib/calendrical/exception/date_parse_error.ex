defmodule Calendrical.DateParseError do
  @moduledoc """
  Raised (or returned as `{:error, _}`) when
  `Calendrical.Date.parse/2` can't interpret an input string as
  a date.

  ### Fields

  * `:message` — human-readable description of the failure.

  * `:input` — the raw string that failed to parse.

  * `:locale` — the locale the parser tried.

  * `:calendar` — the CLDR calendar key the parser tried.

  """

  defexception [:message, :input, :locale, :calendar]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end
end
