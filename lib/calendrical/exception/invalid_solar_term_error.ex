defmodule Calendrical.InvalidSolarTermError do
  @moduledoc """
  Exception returned when a solar term is asked for by a number that names
  none: the twenty-four solar terms are numbered `1` to `24`.

  ### Fields

  * `:index` — the number that was given.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "calendar"]

  defexception [:index]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{index: index}) do
    index = inspect(index)
    ~t"The solar term #{index} is not known. Solar terms are numbered 1 to 24"
  end
end
