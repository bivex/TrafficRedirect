defmodule TrafficRedirect.Infrastructure.Web.Router do
  @moduledoc """
  Regex-based high-performance HTTP router matching the 13 specification routes.
  Injects captured groups (k_router_campaign, k_router_key, version) into conn.params.
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

  plug :match
  plug Plug.Parsers, parsers: [:urlencoded, :multipart, :json], json_decoder: Jason
  plug :dispatch

  # 1. Postback Routes: /{key}/postback OR ?postback= OR ?key=
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

  # 2. Ping Domain
  get "/ping" do
    PingDomainHandler.handle(conn)
  end

  # 3. Site Preview
  get "/preview" do
    SitePreviewHandler.handle(conn)
  end

  # 4. Refresh License
  get "/license/refresh" do
    RefreshLicenseHandler.handle(conn)
  end

  # 5. Click API: /click_api/v:version AND /api.php
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

  # 9. Gateway Redirect (/gateway.php)
  get "/gateway.php" do
    GatewayRedirectHandler.handle(conn)
  end

  # 10. Favicon 404
  get "/favicon.ico" do
    NotFoundHandler.handle(conn)
  end

  # 11. Robots.txt
  get "/robots.txt" do
    RobotsHandler.handle(conn)
  end

  # Routes 6, 7, 8, 12, 13 handled by alias or query parameter checks
  match _ do
    params = conn.params || %{}
    path_info = conn.path_info

    cond do
      # 1. Check ?postback= parameter
      Map.has_key?(params, "postback") ->
        PostbackHandler.handle(conn)

      # 2. Check ?ping= parameter
      Map.has_key?(params, "ping") ->
        PingDomainHandler.handle(conn)

      # 3. Check ?preview= parameter
      Map.has_key?(params, "preview") ->
        SitePreviewHandler.handle(conn)

      # 6. Check ?return= parameter (LandingOfferHandler)
      Map.has_key?(params, "return") and Map.get(params, "return") != "jsonp" ->
        LandingOfferHandler.handle(conn)

      # 7. Legacy JS Tracker v2 check
      Map.get(params, "tracker") == "v2" or Map.get(params, "legacy_tracker") == "1" ->
        alias_name = List.first(path_info) || "default"
        conn = update_params(conn, %{"k_router_campaign" => alias_name})
        LegacyTrackerHandler.handle(conn)

      # 8. Tracker script generator check
      Map.has_key?(params, "k_encounter") or Map.get(params, "tracker") == "1" ->
        alias_name = List.first(path_info) || "default"
        conn = update_params(conn, %{"k_router_campaign" => alias_name})
        TrackerScriptHandler.handle(conn)

      # 12. Main Click with alias /{alias}
      path_info != [] ->
        alias_name = List.first(path_info)
        conn = update_params(conn, %{"k_router_campaign" => alias_name})
        ClickHandler.handle(conn)

      # 13. Catch-all Click without alias
      true ->
        ClickHandler.handle(conn)
    end
  end

  defp update_params(conn, new_params) do
    existing = conn.params || %{}
    %{conn | params: Map.merge(existing, new_params)}
  end

  defp parse_int(val, default) do
    if is_binary(val) do
      case Integer.parse(val) do
        {num, _} -> num
        :error -> default
      end
    else
      default
    end
  end
end
