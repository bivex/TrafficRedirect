defmodule TrafficRedirect.Infrastructure.Web.Endpoint do
  @moduledoc """
  Web Endpoint Plug pipeline.
  Normalizes headers, injects content-length, and delegates to the Router.
  """
  use Plug.Builder

  plug Plug.Logger
  plug :normalize_headers
  plug TrafficRedirect.Infrastructure.Web.Router

  defp normalize_headers(conn, _opts) do
    # Register before_send hook to normalize headers & compute content-length
    Plug.Conn.register_before_send(conn, fn c ->
      body_size = byte_size(c.resp_body || "")
      c
      |> Plug.Conn.put_resp_header("server", "TrafficRedirect-Engine/1.0 (Elixir/BEAM)")
      |> Plug.Conn.put_resp_header("content-length", to_string(body_size))
    end)
  end
end
