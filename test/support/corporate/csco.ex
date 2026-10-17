defmodule Calendrical.CSCO do
  use Calendrical.Calendar.Weeks, year_ends: {:saturday, :on_or_after, {7, 25}}
end
