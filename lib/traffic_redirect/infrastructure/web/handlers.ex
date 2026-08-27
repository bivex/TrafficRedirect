defmodule TrafficRedirect.Infrastructure.Web.RenderHelper do
  @moduledoc false
  import Plug.Conn
  alias TrafficRedirect.Domain.Model.RedirectResponse

  def render_response(conn, %RedirectResponse{} = resp) do
    conn_with_headers =
      Enum.reduce(resp.headers || %{}, conn, fn {k, v}, c ->
        put_resp_header(c, k, to_string(v))
      end)

    conn_with_headers
    |> send_resp(resp.status, resp.body || "")
  end
end

# 1. PostbackHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.PostbackHandler do
  import Plug.Conn
  alias TrafficRedirect.Application.Services.PostbackService

  def handle(conn) do
    params = conn.params || %{}
    case PostbackService.process_postback(params) do
      {:ok, conversion} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"status" => "success", "sub_id" => conversion.sub_id}))

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{"status" => "error", "message" => to_string(reason)}))
    end
  end
end

# 2. PingDomainHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.PingDomainHandler do
  import Plug.Conn
  def handle(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "pong")
  end
end

# 3. SitePreviewHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.SitePreviewHandler do
  import Plug.Conn
  def handle(conn) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, "<h1>Landing Preview Mode</h1>")
  end
end

# 4. RefreshLicenseHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.RefreshLicenseHandler do
  import Plug.Conn
  def handle(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{"status" => "valid", "licensed_to" => "Enterprise"}))
  end
end

# 5. ClickApiHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.ClickApiHandler do
  alias TrafficRedirect.Application.Services.ClickApiService
  alias TrafficRedirect.Infrastructure.Web.RenderHelper

  def handle(conn, version \\ 1) do
    req_data = extract_request(conn)
    {:ok, resp} = ClickApiService.process_click_api(version, req_data)
    RenderHelper.render_response(conn, resp)
  end

  defp extract_request(conn) do
    %{
      headers: Enum.into(conn.req_headers, %{}),
      query_params: conn.params || %{},
      host: conn.host,
      remote_ip: :inet.ntoa(conn.remote_ip) |> to_string(),
      scheme: to_string(conn.scheme)
    }
  end
end

# 6. LandingOfferHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.LandingOfferHandler do
  alias TrafficRedirect.Application.Services.ClickService
  alias TrafficRedirect.Infrastructure.Web.RenderHelper

  def handle(conn) do
    req_data = extract_request(conn)
    {:ok, resp} = ClickService.process_click(req_data)
    RenderHelper.render_response(conn, resp)
  end

  defp extract_request(conn) do
    alias_name = List.first(conn.path_info)
    params =
      if alias_name do
        Map.put(conn.params || %{}, "k_router_campaign", alias_name)
      else
        conn.params || %{}
      end

    %{
      headers: Enum.into(conn.req_headers, %{}),
      query_params: params,
      path_info: conn.path_info,
      request_path: conn.request_path,
      query_string: conn.query_string,
      host: conn.host,
      remote_ip: :inet.ntoa(conn.remote_ip) |> to_string(),
      scheme: to_string(conn.scheme)
    }
  end
end

# 7. LegacyTrackerHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.LegacyTrackerHandler do
  alias TrafficRedirect.Infrastructure.Web.Handlers.TrackerScriptHandler

  def handle(conn) do
    TrackerScriptHandler.handle(conn)
  end
end

# 8. TrackerScriptHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.TrackerScriptHandler do
  import Plug.Conn
  alias TrafficRedirect.Application.Services.TrackerScriptService

  def handle(conn) do
    alias_name = Map.get(conn.params, "k_router_campaign", "default")
    script = TrackerScriptService.get_script(alias_name, %{host: conn.host})

    conn
    |> put_resp_content_type("application/javascript")
    |> send_resp(200, script)
  end
end

# 9. GatewayRedirectHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.GatewayRedirectHandler do
  import Plug.Conn
  alias TrafficRedirect.Domain.Action.RedirectService

  def handle(conn) do
    token = Map.get(conn.params, "token", "")
    ua = Enum.find_value(conn.req_headers, "", fn {k, v} -> if k == "user-agent", do: v end)

    case verify_token(token, ua) do
      {:ok, target_url} ->
        html = RedirectService.meta_redirect(target_url, %{delay: 1})
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)

      {:error, _reason} ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(403, "<h1>Invalid Gateway Token</h1>")
    end
  end

  defp verify_token(token, ua) do
    case String.split(token, ".") do
      [header_b64, payload_b64, sig_b64] ->
        secret = Application.get_env(:traffic_redirect, :gateway_secret, "traffic_redirect_secret_key_2026")
        derived_key = :crypto.mac(:hmac, :sha256, secret, ua)
        signing_input = "#{header_b64}.#{payload_b64}"
        expected_sig = Base.url_encode64(:crypto.mac(:hmac, :sha256, derived_key, signing_input), padding: false)

        if Plug.Crypto.secure_compare(sig_b64, expected_sig) do
          case Base.url_decode64(payload_b64, padding: false) do
            {:ok, json_str} ->
              claims = Jason.decode!(json_str)
              if claims["exp"] && claims["exp"] > System.os_time(:second) do
                {:ok, claims["url"]}
              else
                {:error, :token_expired}
              end

            _ ->
              {:error, :invalid_payload}
          end
        else
          {:error, :invalid_signature}
        end

      _ ->
        {:error, :malformed_token}
    end
  end
end

# 10. NotFoundHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.NotFoundHandler do
  import Plug.Conn
  def handle(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
  end
end

# 11. RobotsHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.RobotsHandler do
  import Plug.Conn
  def handle(conn) do
    content = "User-agent: *\nDisallow: /\n"
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, content)
  end
end

# 12. ClickHandler
defmodule TrafficRedirect.Infrastructure.Web.Handlers.ClickHandler do
  alias TrafficRedirect.Application.Services.ClickService
  alias TrafficRedirect.Infrastructure.Web.RenderHelper

  def handle(conn) do
    req_data = %{
      headers: Enum.into(conn.req_headers, %{}),
      query_params: conn.params || %{},
      path_info: conn.path_info,
      request_path: conn.request_path,
      query_string: conn.query_string,
      host: conn.host,
      remote_ip: :inet.ntoa(conn.remote_ip) |> to_string(),
      scheme: to_string(conn.scheme)
    }

    {:ok, resp} = ClickService.process_click(req_data)
    RenderHelper.render_response(conn, resp)
  end
end
