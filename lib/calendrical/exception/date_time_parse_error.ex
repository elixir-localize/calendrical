defmodule Calendrical.DateTimeParseError do
  @moduledoc """
  Returned (or raised) by `Calendrical.DateTime.parse/2` when an input
  string cannot be interpreted as a datetime.

  Carries semantic fields only; the human-readable description is
  materialised by `message/1` so callers can pattern-match on
  structure (input/locale) without parsing prose.

  ### Fields

  * `:input` — the raw string that failed to parse.

  * `:locale` — the locale the parser tried.

  """

  defexception [:input, :locale]

  @type t :: %__MODULE__{
          input: String.t() | nil,
          locale: atom() | String.t() | nil
        }

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{input: input, locale: locale}) do
    "could not parse #{inspect(input)} as a datetime in locale #{inspect(locale)}; " <>
      "ISO-8601 (YYYY-MM-DDTHH:MM:SS[Z|±HH:MM]) is always accepted as a fallback"
  end
end
