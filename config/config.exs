# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :vin, VinWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Xv9tZ7DfSEaIBXAgoOxPmRNOYNNrJ9wnD+8dC1huGa9DBhLFQ1pWC4yK85DMExgd",
  render_errors: [view: VinWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Vin.PubSub,
  live_view: [signing_salt: "8ztEXhuE"]

# Configures Elixir's Logger
config :logger,
  backends: [{LoggerFileBackend, :log_file}]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
