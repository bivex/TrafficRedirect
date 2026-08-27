import Config

config :traffic_redirect,
  port: 4000,
  gateway_secret: "traffic_redirect_default_secret_2026",
  disable_stats: false,
  force_ssl: false

import_config "#{config_env()}.exs"
