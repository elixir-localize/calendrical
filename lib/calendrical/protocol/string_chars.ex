defimpl String.Chars, for: Calendrical.Duration do
  def to_string(duration) do
    locale = Localize.get_locale()
    Calendrical.Duration.to_string!(duration, locale: locale)
  end
end
