defmodule Calendrical.InvalidOptionValueError do
  @moduledoc """
  Exception returned, or raised by a calendar maker, when an option is given
  a value it cannot take: an unknown `:day_start`, a `:nightfall_angle` that
  is not a number, a `:location` that is not a place, or a calendar maker's
  option in a form it does not take.

  ### Fields

  * `:option` — the option that was given.

  * `:value` — the value it was given.

  * `:maker` — the calendar maker the option was given to, such as
    `Calendrical.Calendar.Weeks`, or `nil` for a function's option.

  """

  use Localize.Message.Sigils,
    backend: Calendrical.Gettext,
    sigils: [domain: "calendrical", context: "option"]

  defexception [:option, :value, :maker]

  @impl true
  def exception(bindings) when is_list(bindings) do
    struct!(__MODULE__, bindings)
  end

  @impl true
  def message(%__MODULE__{option: :weeks, value: value, maker: maker}) when not is_nil(maker) do
    value = inspect(value)
    ~t":weeks must be a keyword list or :from_first_day. Found #{value}"
  end

  def message(%__MODULE__{option: :months_in_year, value: value, maker: maker})
      when not is_nil(maker) do
    value = inspect(value)
    form = "{fewest, most}"
    ~t":months_in_year must be a count, or #{form}. Found #{value}"
  end

  def message(%__MODULE__{option: :year_begins, value: value, maker: Calendrical.Calendar.Weeks}) do
    value = inspect(value)

    form = "{weekday, :on_or_before, {month, day}}"
    nearest = "{weekday, :nearest, {month, 4}}"

    ~t":year_begins must be #{form} with the day 1 to 7, or #{nearest}. Found #{value}"
  end

  def message(%__MODULE__{option: :year_begins, value: value, maker: maker})
      when not is_nil(maker) do
    value = inspect(value)
    form = "{month, day}"
    ~t":year_begins must be #{form} of the base calendar. Found #{value}"
  end

  def message(%__MODULE__{option: :year_ends, value: value, maker: maker})
      when not is_nil(maker) do
    value = inspect(value)

    form = "{weekday, :on_or_after, {month, day}}"
    nearest = "{weekday, :nearest, {month, last_day}}"

    ~t":year_ends must be #{form} with the day in the month's last seven, or #{nearest}. Found #{value}"
  end

  def message(%__MODULE__{option: [:year_begins, :year_ends], maker: maker})
      when not is_nil(maker) do
    ~t"A calendar of weeks takes :year_begins or :year_ends, not both"
  end

  def message(%__MODULE__{option: :pattern, value: value, maker: maker}) when not is_nil(maker) do
    value = inspect(value)
    ~t":pattern must be [4, 4, 5], [4, 5, 4] or [5, 4, 4]. Found #{value}"
  end

  def message(%__MODULE__{option: :year_number, value: value, maker: maker})
      when not is_nil(maker) do
    value = inspect(value)
    ~t":year_number must be :beginning, :ending or :majority. Found #{value}"
  end

  def message(%__MODULE__{option: :written_year, value: value, maker: maker})
      when not is_nil(maker) do
    value = inspect(value)
    ~t":written_year must be :base or :label. Found #{value}"
  end

  def message(%__MODULE__{option: :cldr_calendar_type, value: value, maker: maker})
      when not is_nil(maker) do
    value = inspect(value)
    ~t":cldr_calendar_type must be :gregorian or :japanese. Found #{value}"
  end

  def message(%__MODULE__{option: :base, value: value, maker: maker}) when not is_nil(maker) do
    value = inspect(value)

    ~t"The base calendar #{value} has a different number of months in different years. A shifted year needs a base with as many months in every year"
  end

  def message(%__MODULE__{option: :options, value: value}) do
    value = inspect(value)
    ~t"The options must be a keyword list. Found #{value}"
  end

  def message(%__MODULE__{option: option, value: value}) do
    option = inspect(option)
    value = inspect(value)
    ~t"The option #{option} cannot take the value #{value}"
  end
end
