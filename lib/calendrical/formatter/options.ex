defmodule Calendrical.Formatter.Options do
  @moduledoc false
  @valid_options [
    :locale,
    :calendar,
    :caption,
    :class,
    :day_names,
    :formatter,
    :id,
    :number_system,
    :private,
    :territory,
    :today
  ]

  defstruct @valid_options

  @typedoc """
  Formatter options

  """
  @type t :: %__MODULE__{
          calendar: module(),
          number_system: atom(),
          territory: atom() | String.t(),
          locale: Localize.LanguageTag.t(),
          formatter: module(),
          caption: String.t() | nil,
          class: String.t() | nil,
          id: String.t() | nil,
          today: Date.t(),
          private: any(),
          day_names: [{1..7, String.t()}]
        }

  @doc false
  def validate_options(options) when is_list(options) do
    # Silently ignore :backend if passed (backward compatibility)
    options = Keyword.delete(options, :backend)

    options =
      Enum.reduce_while(@valid_options, options, fn option, options ->
        case validate_option(option, options, Keyword.get(options, option)) do
          {:ok, value} -> {:cont, Keyword.put(options, option, value)}
          other -> {:halt, other}
        end
      end)

    case options do
      {:error, _} = error -> error
      valid_options -> {:ok, struct(__MODULE__, valid_options)}
    end
  end

  def validate_option(:calendar, _options, nil) do
    {:ok, Calendrical.default_calendar()}
  end

  def validate_option(:calendar, _options, Calendar.ISO) do
    {:ok, Calendrical.default_calendar()}
  end

  def validate_option(:calendar, _options, calendar) do
    with {:ok, calendar} <- Calendrical.validate_calendar(calendar) do
      {:ok, calendar}
    end
  end

  def validate_option(:number_system, options, nil) do
    locale = Keyword.get(options, :locale)
    Localize.Number.System.number_system_from_locale(locale)
  end

  def validate_option(:number_system, _options, number_system) do
    Localize.validate_number_system(number_system)
  end

  def validate_option(:territory, options, nil) do
    locale = Keyword.get(options, :locale)
    Localize.Territory.territory_from_locale(locale)
  end

  def validate_option(:formatter, _options, nil) do
    {:ok, Calendrical.Format.default_formatter_module()}
  end

  def validate_option(:formatter, _options, formatter) do
    if Calendrical.Format.formatter_module?(formatter) do
      {:ok, formatter}
    else
      {:error, Calendrical.Format.invalid_formatter_error(formatter)}
    end
  end

  def validate_option(:locale, _options, nil) do
    {:ok, Localize.get_locale()}
  end

  def validate_option(:locale, _options, locale) do
    with {:ok, locale} <- Localize.validate_locale(locale) do
      {:ok, locale}
    end
  end

  def validate_option(:today, _options, nil) do
    {:ok, Date.utc_today()}
  end

  def validate_option(:today, _options, date) do
    if is_map(date) and Map.has_key?(date, :year) and
         Map.has_key?(date, :month) and Map.has_key?(date, :day) do
      {:ok, date}
    else
      {:error, Calendrical.Format.invalid_date_error(date)}
    end
  end

  def validate_option(:class, _options, nil) do
    {:ok, Calendrical.Format.default_calendar_css_class()}
  end

  def validate_option(:class, _options, class) do
    {:ok, class}
  end

  def validate_option(:caption, _options, nil) do
    {:ok, nil}
  end

  def validate_option(:caption, _options, caption) do
    {:ok, caption}
  end

  def validate_option(:id, _options, nil) do
    {:ok, nil}
  end

  def validate_option(:id, _options, id) do
    {:ok, id}
  end

  def validate_option(:private, _options, nil) do
    {:ok, nil}
  end

  def validate_option(:private, _options, private) do
    {:ok, private}
  end

  def validate_option(:day_names, options, nil) do
    locale = Keyword.get(options, :locale)

    {:ok, date} = Date.new(2000, 1, 1, Keyword.get(options, :calendar))
    {:ok, Calendrical.localize(date, :days_of_week, locale: locale)}
  end

  day_names =
    quote do
      [{1, _}, {2, _}, {3, _}, {4, _}, {5, _}, {6, _}, {7, _}]
    end

  def validate_option(:day_names, _options, unquote(day_names) = day_names) do
    {:ok, day_names}
  end

  def validate_option(option, _options, any) do
    {:error, Calendrical.Formatter.InvalidOptionError.exception(option: option, value: any)}
  end
end
