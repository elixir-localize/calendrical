defmodule Calendrical.Gettext do
  @moduledoc false

  # Gettext backend for the Calendrical library.
  #
  # Provides localized error messages for exceptions using
  # the GNU Gettext internationalization framework. Messages
  # are written in MessageFormat 2, with `{$name}` placeholders,
  # and are interpolated by Localize. They use the `"calendrical"`
  # domain and are organized by context (`msgctxt`) corresponding
  # to the area of concern: `"calendar"`, `"date"`, `"format"`,
  # `"option"` and `"style"`.
  #

  use Gettext.Backend,
    otp_app: :calendrical,
    interpolation: Localize.Gettext.Interpolation
end
