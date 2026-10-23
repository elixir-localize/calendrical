defmodule Calendrical.UnknownOptionError do
  @moduledoc """
  Exception raised by a calendar maker (`use Calendrical.Calendar` and the
  others), and returned by `Calendrical.new/3` and
  `Calendrical.Composite.new/2`, for options the maker does not read.

  ### Fields

  * `:maker` — the maker the options were given to, such as
    `Calendrical.Calendar.Weeks`.

  * `:options` — the options it does not read.

  * `:known_options` — the options it reads.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "option"]

  defexception [:maker, :options, :known_options]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{maker: maker, options: options, known_options: known_options}) do
    maker = inspect(maker)
    options = inspect(options)
    known_options = inspect(known_options)
    ~t"#{maker} does not read the options #{options}. The options are #{known_options}"
  end
end
