use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :vin, VinWeb.Endpoint,
  http: [port: 4002],
  server: false

config :logger, :log_file,
  level: :info,
  format: "$time $metadata [$level]: $message\n",
  metadata: [:request_id, :file, :line, :mfa],
  path: "log/test.log"
