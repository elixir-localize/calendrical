defmodule Calendrical.Era.Names do
  @moduledoc false

  # A calendar's own names for its eras, where CLDR's data names none of
  # its own: the Bangla calendars take their month names from CLDR's Indian
  # calendar but count their years in the Bangla era, not the Śaka. A
  # calendar states its names in English (`c:Calendrical.info/0`'s
  # `era_names`), and each is a message of Calendrical's `"eras"` domain
  # (`priv/gettext/eras.pot`) in the `"era"` context, translated for the
  # locale asked; a name with no translation is the English. Localize asks
  # a calendar's `era_names/1` and takes CLDR's names where it answers
  # `:cldr`.

  alias Localize.LanguageTag

  @domain "eras"
  @context "era"
  @styles [:wide, :abbreviated, :narrow]

  @doc "A calendar's own era names in a locale, by style then era, or `:cldr`."
  @spec era_names(module(), Localize.locale()) ::
          {:ok, %{atom() => %{integer() => String.t()}}} | :cldr | {:error, Exception.t()}
  def era_names(calendar, locale) do
    names = calendar.info().era_names

    if is_nil(names) do
      :cldr
    else
      translated(names, locale)
    end
  end

  defp translated(names, locale) do
    with {:ok, language_tag} <- Localize.validate_locale(locale) do
      catalog_locales = catalog_locales(language_tag)

      {:ok,
       for style <- @styles, into: %{} do
         {style, Map.new(names, &era_name(&1, style, catalog_locales))}
       end}
    end
  end

  defp era_name({era, by_style}, style, catalog_locales) do
    message = Map.fetch!(by_style, style)
    {era, Enum.find_value(catalog_locales, message, &translation(&1, message))}
  end

  # A backend's `lgettext/5` takes the locale, so none is put in the process.
  defp translation(catalog_locale, message) do
    case Calendrical.Gettext.lgettext(catalog_locale, @domain, @context, message, %{}) do
      {:ok, translation} -> translation
      _untranslated -> nil
    end
  end

  # The locale's language with its territory, then its language alone, as
  # Gettext writes them (`bn_BD`, `bn`).
  defp catalog_locales(%LanguageTag{language: language, territory: nil}) do
    [Atom.to_string(language)]
  end

  defp catalog_locales(%LanguageTag{language: language, territory: territory}) do
    language = Atom.to_string(language)
    [language <> "_" <> Atom.to_string(territory), language]
  end
end
