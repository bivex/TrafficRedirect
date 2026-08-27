defmodule TrafficRedirect.Infrastructure.Adapters.Storage.Repo do
  @moduledoc """
  Ecto Postgres Repository for persisting batched clicks and analytics.
  """
  use Ecto.Repo,
    otp_app: :traffic_redirect,
    adapter: Ecto.Adapters.Postgres
end
