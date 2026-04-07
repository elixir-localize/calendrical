defmodule Calendrical.Gettext do
  @moduledoc """
  Gettext backend for the Calendrical library.

  Provides localized error messages for exceptions using
  the GNU Gettext internationalization framework. Messages
  use the `"calendrical"` domain and are organized by context
  (`msgctxt`) corresponding to the area of concern: `"calendar"`,
  `"date"`, `"format"`, `"option"`.

  """

  use Gettext.Backend, otp_app: :calendrical
end
