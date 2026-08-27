defmodule TrafficRedirect.Infrastructure.Web.Router do
  @moduledoc """
  Ordered regex-based HTTP router matching the 13 specification routes.
  Route priority: first match wins.
  Captured groups (k_router_campaign, k_router_key, version) are injected into conn.params.

  ## Route Table (13 routes, spec §3.1)
  | #  | Pattern                                       | Handler                | Purpose                        |
  |----|-----------------------------------------------|------------------------|--------------------------------|
  | 1  | /{key}/postback, /postback, ?postback=, ?key= | PostbackHandler        | Conversion postback ingestion  |
  | 2  | /ping, ?ping=                                 | PingDomainHandler      | Domain health check            |
  | 3  | /preview, ?preview=                           | SitePreviewHandler     | Landing preview                |
  | 4  | /license/refresh                              | RefreshLicenseHandler  | License refresh                |
  | 5  | /click_api/v{n} (v1-v4), /api.php             | ClickApiHandler        | Server-to-server Click API     |
  | 6  | ?return= (not jsonp)                          | LandingOfferHandler    | Offer click from landing page  |
  | 7  | /{alias}?tracker=v2 or ?legacy_tracker=1      | LegacyTrackerHandler   | Legacy JS tracker              |
  | 8  | /{alias}?k_encounter=2 or ?tracker=1          | TrackerScriptHandler   | IIFE JS tracker script         |
  | 9  | /gateway.php?frm=dm&token=...                 | GatewayRedirectHandler | Double-meta intermediate hop   |
  | 10 | /favicon.ico                                  | NotFoundHandler        | 404                            |
  | 11 | /robots.txt                                   | RobotsHandler          | Robots disallow                |
  | 12 | /{alias}                                      | ClickHandler           | Main click → redirect          |
  | 13 | catch-all                                     | ClickHandler           | Click without alias            |
  """
  use Plug.Router

  alias TrafficRedirect.Infrastructure.Web.Handlers.{
    ClickHandler,
    ClickApiHandler,
    GatewayRedirectHandler,
    LandingOfferHandler,
    LegacyTrackerHandler,
    NotFoundHandler,
    PingDomainHandler,
    PostbackHandler,
    RefreshLicenseHandler,
    RobotsHandler,
    SitePreviewHandler,
    TrackerScriptHandler
  }

  plug :fetch_query_params
  plug :match
  plug :maybe_parse_body
  plug :dispatch

  @parsers_opts Plug.Parsers.init(parsers: [:urlencoded, :multipart, :json], json_decoder: Jason)

  defp maybe_parse_body(%Plug.Conn{method: method} = conn, _opts) when method in ["POST", "PUT", "PATCH"] do
    Plug.Parsers.call(conn, @parsers_opts)
  end
  defp maybe_parse_body(conn, _opts), do: conn

  # ──────────────────────────────────────────────────────────────────────────
  # Route 1: Postback – static path patterns (query-param variants in match _)
  # ──────────────────────────────────────────────────────────────────────────

  get "/:key/postback" do
    conn = update_params(conn, %{"k_router_key" => key, "key" => key})
    PostbackHandler.handle(conn)
  end

  post "/:key/postback" do
    conn = update_params(conn, %{"k_router_key" => key, "key" => key})
    PostbackHandler.handle(conn)
  end

  get "/postback" do
    PostbackHandler.handle(conn)
  end

  post "/postback" do
    PostbackHandler.handle(conn)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Route 2: Ping Domain
  # ──────────────────────────────────────────────────────────────────────────

  get "/ping" do
    PingDomainHandler.handle(conn)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Route 3: Site Preview
  # ──────────────────────────────────────────────────────────────────────────

  get "/preview" do
    SitePreviewHandler.handle(conn)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Route 4: License Refresh
  # ──────────────────────────────────────────────────────────────────────────

  get "/license/refresh" do
    RefreshLicenseHandler.handle(conn)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Route 5: Click API – /click_api/v{n} (v1-v4) and legacy /api.php
  # ──────────────────────────────────────────────────────────────────────────

  get "/click_api/v:version" do
    ver = parse_int(version, 1)
    conn = update_params(conn, %{"version" => ver})
    ClickApiHandler.handle(conn, ver)
  end

  post "/click_api/v:version" do
    ver = parse_int(version, 1)
    conn = update_params(conn, %{"version" => ver})
    ClickApiHandler.handle(conn, ver)
  end

  get "/api.php" do
    ClickApiHandler.handle(conn, 1)
  end

  post "/api.php" do
    ClickApiHandler.handle(conn, 1)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Route 9: Gateway Redirect – double-meta intermediate hop
  # ──────────────────────────────────────────────────────────────────────────

  get "/gateway.php" do
    GatewayRedirectHandler.handle(conn)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Route 10: Favicon → 404
  # ──────────────────────────────────────────────────────────────────────────

  get "/favicon.ico" do
    NotFoundHandler.handle(conn)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Route 11: Robots
  # ──────────────────────────────────────────────────────────────────────────

  get "/robots.txt" do
    RobotsHandler.handle(conn)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Routes 1(q), 2(q), 3(q), 6, 7, 8, 12, 13 — query-param based dispatch
  # Priority order matches spec §3.1 table
  # ──────────────────────────────────────────────────────────────────────────

  match _ do
    params    = conn.params || %{}
    path_info = conn.path_info

    cond do
      # Route 1 (query variant): ?postback= or ?key=
      Map.has_key?(params, "postback") or Map.has_key?(params, "key") and Map.has_key?(params, "sub_id") ->
        PostbackHandler.handle(conn)

      # Route 2 (query variant): ?ping=
      Map.has_key?(params, "ping") ->
        PingDomainHandler.handle(conn)

      # Route 3 (query variant): ?preview=
      Map.has_key?(params, "preview") ->
        SitePreviewHandler.handle(conn)

      # Route 6: ?return= (but not ?return=jsonp – that is pixel/jsonp action)
      Map.has_key?(params, "return") and Map.get(params, "return") != "jsonp" ->
        LandingOfferHandler.handle(conn)

      # Route 7: Legacy JS Tracker v2 – ?tracker=v2 or ?legacy_tracker=1
      Map.get(params, "tracker") == "v2" or Map.get(params, "legacy_tracker") == "1" ->
        alias_name = List.first(path_info) || "default"
        conn = update_params(conn, %{"k_router_campaign" => alias_name})
        LegacyTrackerHandler.handle(conn)

      # Route 8: IIFE Tracker Script – ?k_encounter=2 or ?tracker=1
      Map.has_key?(params, "k_encounter") or Map.get(params, "tracker") == "1" ->
        alias_name = List.first(path_info) || "default"
        conn = update_params(conn, %{"k_router_campaign" => alias_name})
        TrackerScriptHandler.handle(conn)

      # Route 12: Main click with campaign alias /{alias}
      path_info != [] ->
        alias_name = List.first(path_info)
        conn = update_params(conn, %{"k_router_campaign" => alias_name})
        ClickHandler.handle(conn)

      # Route 13: Catch-all click (no alias in path)
      true ->
        ClickHandler.handle(conn)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Private helpers
  # ──────────────────────────────────────────────────────────────────────────

  defp update_params(conn, new_params) do
    existing = conn.params || %{}
    %{conn | params: Map.merge(existing, new_params)}
  end

  defp parse_int(val, default) do
    if is_binary(val) do
      case Integer.parse(val) do
        {num, _} -> num
        :error   -> default
      end
    else
      default
    end
  end
end
