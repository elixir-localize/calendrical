defmodule Calendrical.Formatter.UnknownFormatterError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Calendrical.Formatter.InvalidDateError do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end

defmodule Calendrical.Formatter.InvalidOption do
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end
