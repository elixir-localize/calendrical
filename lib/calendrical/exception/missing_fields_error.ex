defmodule Calendrical.MissingFieldsError do
  @moduledoc """
  Exception raised when a date or datetime does not have all
  the fields required by the function being called.

  ### Fields

  * `:function` — the name of the function that required the
    fields, as a string.

  * `:fields` — a keyword list whose keys are the required field
    names and whose values are the values that were found
    (`nil` for missing fields).

  """

  defexception [:function, :fields]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{function: function, fields: fields}) do
    required = fields |> Keyword.keys() |> Enum.join(", ")
    found = Enum.map_join(fields, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)

    Gettext.dpgettext(
      Calendrical.Gettext,
      "calendrical",
      "date",
      "%{function} requires at least %{required}. Found %{found}",
      function: function,
      required: required,
      found: found
    )
  end
end
