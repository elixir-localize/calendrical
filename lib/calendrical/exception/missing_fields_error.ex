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

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "date"]

  defexception [:function, :fields]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{function: function, fields: fields}) do
    function = name(function)
    required = required(fields)
    found = found(fields)

    ~t"#{function} requires at least #{required}. Found #{found}"
  end

  # The fields are a keyword list of the fields the function needs and
  # the value a date had for each. Whatever else an exception was built
  # with is shown as it is: a message is no place to raise.
  defp required(fields) do
    each(fields, fn
      {field, _value} when is_atom(field) -> Atom.to_string(field)
      other -> inspect(other)
    end)
  end

  defp found(fields) do
    each(fields, fn
      {field, value} when is_atom(field) -> "#{field}: #{inspect(value)}"
      other -> inspect(other)
    end)
  end

  defp each(fields, entry) when is_list(fields) do
    if List.improper?(fields),
      do: inspect(fields),
      else: Enum.map_join(fields, ", ", entry)
  end

  defp each(fields, _entry), do: inspect(fields)

  defp name(function) when is_binary(function), do: function

  defp name(function) when is_atom(function) and not is_nil(function),
    do: Atom.to_string(function)

  defp name(function), do: inspect(function)
end
