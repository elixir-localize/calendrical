defmodule Calendrical.LunisolarDoc.Test do
  use ExUnit.Case, async: true

  doctest Calendrical.Chinese
  doctest Calendrical.Korean
  doctest Calendrical.LunarJapanese
end
