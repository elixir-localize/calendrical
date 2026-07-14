import Config

# Calendrical is time zone database agnostic: `Calendrical.TimeZone`
# resolves the database from this `:elixir` configuration first, then
# falls back to detecting a loaded implementation. Any
# `Calendar.TimeZoneDatabase` implementation works; `tz` is the
# database used for calendrical's own development and test.
config :elixir, :time_zone_database, Tz.TimeZoneDatabase

if File.exists?(Path.join(__DIR__, "#{config_env()}.exs")) do
  import_config "#{config_env()}.exs"
end
