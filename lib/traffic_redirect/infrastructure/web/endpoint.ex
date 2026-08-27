defmodule TrafficRedirect.Infrastructure.Web.Endpoint do
  @moduledoc """
  Web Endpoint Plug pipeline.
  Normalizes headers, injects content-length, and delegates to the Router with zero unnecessary overhead.
  """
  use Plug.Builder

  plug :maybe_log
  plug :normalize_headers
  plug TrafficRedirect.Infrastructure.Web.Router

  defp maybe_log(conn, opts) do
    if Application.get_env(:traffic_redirect, :enable_logger, false) do
      Plug.Logger.call(conn, Plug.Logger.init(opts))
    else
      conn
    end
  end

  defp normalize_headers(conn, _opts) do
    Plug.Conn.register_before_send(conn, fn c ->
      body_size = byte_size(c.resp_body || "")
      c
      |> Plug.Conn.put_resp_header("server", "TrafficRedirect-Engine/1.0 (Elixir/BEAM)")
      |> Plug.Conn.put_resp_header("content-length", to_string(body_size))
    end)
  end
end
