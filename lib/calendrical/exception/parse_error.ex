defmodule Calendrical.ParseError do
  @moduledoc """
  Returned (or raised) by `Calendrical.parse/2` when no sub-parser
  could interpret the input as a date, time, datetime, or date
  range.

  Carries semantic fields only; the human-readable description is
  materialised by `message/1`. Inspect `:attempts` to see what each
  sub-parser reported.

  ### Fields

  * `:input` — the raw string that failed to parse.

  * `:locale` — the locale the parser tried.

  * `:attempts` — keyword list of `{kind, exception}` recording
    each sub-parser that was tried and the exception it returned,
    in the order they were attempted. `kind` is one of
    `:interval`, `:date`, `:time`, `:datetime`.

  """

  defexception [:input, :locale, :attempts]

  @type kind :: :interval | :date | :time | :datetime
  @type attempt :: {kind(), Exception.t()}
  @type t :: %__MODULE__{
          input: String.t() | nil,
          locale: atom() | String.t() | nil,
          attempts: [attempt()] | nil
        }

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{input: input, locale: locale}) do
    "could not parse #{inspect(input)} as a date, time, datetime, or " <>
      "interval in locale #{inspect(locale)}"
  end
end
