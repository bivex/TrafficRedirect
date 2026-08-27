import Config

database_url = System.get_env("DATABASE_URL")

if database_url do
  config :traffic_redirect, TrafficRedirect.Infrastructure.Adapters.Storage.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "20"),
    queue_target: 500,
    queue_interval: 1000
end

if config_env() == :prod do
  port = String.to_integer(System.get_env("PORT") || "4000")
  gateway_secret = System.get_env("GATEWAY_SECRET") || "traffic_redirect_prod_secret_key_change_me"
  disable_stats = System.get_env("DISABLE_STATS") in ["true", "1"]
  force_ssl = System.get_env("FORCE_SSL") in ["true", "1"]

  config :traffic_redirect,
    port: port,
    gateway_secret: gateway_secret,
    disable_stats: disable_stats,
    force_ssl: force_ssl
end
