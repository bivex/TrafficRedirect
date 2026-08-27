defmodule TrafficRedirect.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:traffic_redirect, :port, 4000)

    repo_child =
      if Application.get_env(:traffic_redirect, TrafficRedirect.Infrastructure.Adapters.Storage.Repo) do
        [TrafficRedirect.Infrastructure.Adapters.Storage.Repo]
      else
        []
      end

    children =
      repo_child ++
        [
          # 1. High performance ETS in-memory storage
          TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStorage,
          # 2. Async Click batch buffer worker
          TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker,
          # 3. Async Postback sender worker
          TrafficRedirect.Infrastructure.Adapters.Queue.PostbackSenderWorker,
          # 4. Outgoing HTTP client pool
          {Finch, name: TrafficRedirect.Finch},
          # 5. Bandit high-performance HTTP web server
          {Bandit, plug: TrafficRedirect.Infrastructure.Web.Endpoint, port: port}
        ]

    opts = [strategy: :one_for_one, name: TrafficRedirect.Supervisor]
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        TrafficRedirect.Infrastructure.Adapters.Storage.DbInit.ensure_tables_exist()
        {:ok, pid}

      other ->
        other
    end
  end
end
