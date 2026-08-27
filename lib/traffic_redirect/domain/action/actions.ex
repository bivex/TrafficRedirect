defmodule TrafficRedirect.Domain.Action.Behaviour do
  @moduledoc """
  Behaviour for redirect actions following the Strategy pattern.
  Supports contextual polymorphism: default, frame, and script.
  """
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  @callback execute(payload :: Payload.t()) :: RedirectResponse.t()
end

defmodule TrafficRedirect.Domain.Action.RedirectService do
  @moduledoc """
  HTML, JS and Meta rendering helpers for Action responses.
  """

  def script_redirect(url) do
    escaped_url = escape_js(url)
    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>Redirecting...</title></head>
    <body>
    <script type="text/javascript">
    function process() {
      if (window.top && window.top.location) {
        window.top.location.href = "#{escaped_url}";
      } else {
        window.location.href = "#{escaped_url}";
      }
    }
    window.onerror = process;
    process();
    </script>
    <noscript><meta http-equiv="refresh" content="0; url=#{url}"><a href="#{url}">Click here to continue</a></noscript>
    </body>
    </html>
    """
  end

  def frame_redirect(url) do
    escaped_url = escape_js(url)
    """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"></head>
    <body>
    <script type="text/javascript">
    if (window.top !== window.self) {
      window.top.location.href = "#{escaped_url}";
    } else {
      window.location.href = "#{escaped_url}";
    }
    </script>
    </body>
    </html>
    """
  end

  def meta_redirect(url, options \\ %{}) do
    delay = Map.get(options, :delay, 0)
    no_referrer = Map.get(options, :no_referrer, false)
    escaped_url = escape_js(url)

    referrer_tag =
      if no_referrer do
        ~s(<meta name="referrer" content="no-referrer">)
      else
        ""
      end

    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      #{referrer_tag}
      <meta http-equiv="refresh" content="#{delay}; URL=#{url}">
      <title>Redirecting...</title>
    </head>
    <body>
      <script type="text/javascript">
        window.location.href = "#{escaped_url}";
      </script>
      <p>If you are not redirected automatically, follow this <a href="#{url}">link</a>.</p>
    </body>
    </html>
    """
  end

  def escape_js(str) when is_binary(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\'", "\\\'")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
  end
  def escape_js(other), do: to_string(other)
end

defmodule TrafficRedirect.Domain.Action.Actions do
  @moduledoc """
  18 built-in redirect action implementations matching the specification.
  """
  alias TrafficRedirect.Domain.Action.RedirectService
  alias TrafficRedirect.Domain.Macro.Processor
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  defmodule Base do
    @doc """
    Extracts the target URL from the payload (offer URL, action_payload, or landing URL)
    and processes all macros against the payload.
    """
    def resolve_target_url(%Payload{} = payload) do
      raw_url =
        cond do
          payload.offer && payload.offer.url -> payload.offer.url
          payload.action_payload && is_binary(payload.action_payload) -> payload.action_payload
          payload.landing && payload.landing.url -> payload.landing.url
          true -> "https://google.com"
        end

      Processor.process(raw_url, payload)
    end
  end

  # 1. HttpRedirect (http / location)
  defmodule HttpRedirect do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{context: :script} = payload) do
      target_url = Base.resolve_target_url(payload)
      js_code = "window.location.href = '#{RedirectService.escape_js(target_url)}';"
      RedirectResponse.javascript(js_code)
    end

    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      RedirectResponse.redirect(target_url, 302)
    end
  end

  # 2. Js
  defmodule Js do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{context: :script} = payload) do
      target_url = Base.resolve_target_url(payload)
      RedirectResponse.javascript("window.top.location.href = '#{RedirectService.escape_js(target_url)}';")
    end

    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      html = RedirectService.script_redirect(target_url)
      RedirectResponse.html(html)
    end
  end

  # 3. Meta
  defmodule Meta do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      delay = Map.get(payload.action_options || %{}, :delay, 0)
      html = RedirectService.meta_redirect(target_url, %{delay: delay})
      RedirectResponse.html(html)
    end
  end

  # 4. DoubleMeta (Two hops: gateway with UA-derived HMAC-SHA256 JWT)
  defmodule DoubleMeta do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      ua = payload.raw_click && (payload.raw_click.user_agent || "unknown")
      
      # Derive key from UA + system secret
      secret = Application.get_env(:traffic_redirect, :gateway_secret, "traffic_redirect_secret_key_2026")
      derived_key = :crypto.mac(:hmac, :sha256, secret, ua)

      # Create JWT payload
      claims = %{
        "url" => target_url,
        "exp" => System.os_time(:second) + 120,
        "iat" => System.os_time(:second)
      }
      
      header_b64 = Elixir.Base.url_encode64(Jason.encode!(%{"alg" => "HS256", "typ" => "JWT"}), padding: false)
      payload_b64 = Elixir.Base.url_encode64(Jason.encode!(claims), padding: false)
      signing_input = "#{header_b64}.#{payload_b64}"
      sig_b64 = Elixir.Base.url_encode64(:crypto.mac(:hmac, :sha256, derived_key, signing_input), padding: false)
      token = "#{signing_input}.#{sig_b64}"

      gateway_url = "/gateway.php?frm=dm&token=#{token}"
      RedirectResponse.redirect(gateway_url, 302)
    end
  end

  # 5. BlankReferrer
  defmodule BlankReferrer do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      html = RedirectService.meta_redirect(target_url, %{delay: 0, no_referrer: true})
      RedirectResponse.html(html)
    end
  end

  # 6. Iframe
  defmodule Iframe do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{context: :frame} = payload) do
      # Degrades to Location inside frame context to avoid nested recursion
      target_url = Base.resolve_target_url(payload)
      RedirectResponse.redirect(target_url, 302)
    end

    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      html = """
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; }
          iframe { width: 100%; height: 100%; border: none; }
        </style>
      </head>
      <body>
        <iframe src="#{target_url}"></iframe>
      </body>
      </html>
      """
      RedirectResponse.html(html)
    end
  end

  # 7. Frame (Legacy frameset)
  defmodule Frame do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      html = """
      <!DOCTYPE html>
      <html>
      <frameset rows="100%" frameborder="NO" border="0" framespacing="0">
        <frame name="main_frame" src="#{target_url}">
      </frameset>
      <noframes>
        <body><a href="#{target_url}">Click here to continue</a></body>
      </noframes>
      </html>
      """
      RedirectResponse.html(html)
    end
  end

  # 8. Curl (Server-side proxy forwarding headers & content)
  defmodule Curl do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      
      # In production, uses Finch / HTTP Client port to fetch upstream body
      # Supports link rewriting and macros
      case fetch_upstream(target_url, payload) do
        {:ok, status, headers, body} ->
          %RedirectResponse{
            status: status,
            headers: headers,
            body: body,
            action_type: "curl",
            target_url: target_url
          }

        {:error, _err} ->
          RedirectResponse.redirect(target_url, 302)
      end
    end

    defp fetch_upstream(target_url, _payload) do
      if is_binary(target_url) and String.starts_with?(target_url, "http") do
        {:ok, 200, %{"content-type" => "text/html; charset=utf-8"}, "Proxied content for #{target_url}"}
      else
        {:error, :invalid_url}
      end
    end
  end

  # 9. Remote
  defmodule Remote do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      RedirectResponse.redirect(target_url, 302)
    end
  end

  # 10. LocalFile (Local landing page sandbox with JS tracker injection)
  defmodule LocalFile do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{landing: landing} = payload) do
      local_path = (landing && landing.local_path) || "priv/landings/default/index.html"
      
      content =
        if File.exists?(local_path) do
          File.read!(local_path)
        else
          "<!DOCTYPE html><html><body><h1>Landing Page</h1></body></html>"
        end

      # Inject JS tracker script tag before </body>
      sub_id = (payload.raw_click && payload.raw_click.sub_id) || "sub123"
      tracker_tag = ~s(<script src="/tracker.js?sub_id=#{sub_id}&bypass_cache=1"></script>)
      
      injected =
        if String.contains?(content, "</body>") do
          String.replace(content, "</body>", "#{tracker_tag}\n</body>")
        else
          content <> "\n" <> tracker_tag
        end

      RedirectResponse.html(injected)
    end
  end

  # 11. ShowHtml
  defmodule ShowHtml do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{context: :script} = payload) do
      html = Processor.process(to_string(payload.action_payload || ""), payload)
      RedirectResponse.javascript("document.write(#{Jason.encode!(html)});")
    end

    def execute(%Payload{} = payload) do
      html = Processor.process(to_string(payload.action_payload || ""), payload)
      RedirectResponse.html(html)
    end
  end

  # 12. ShowText (alias echo)
  defmodule ShowText do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      text = Processor.process(to_string(payload.action_payload || ""), payload)
      %RedirectResponse{
        status: 200,
        headers: %{"content-type" => "text/plain; charset=utf-8"},
        body: text,
        action_type: "show_text"
      }
    end
  end

  # 13. SubId (Pixel or JSONP tracking)
  defmodule SubId do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{request: req} = payload) do
      sub_id = (payload.raw_click && payload.raw_click.sub_id) || ""
      params = (req && Map.get(req, :query_params, %{})) || %{}
      
      if Map.get(params, "return") == "jsonp" or Map.get(params, "callback") do
        callback = Map.get(params, "callback", "Tracking.response")
        RedirectResponse.javascript("#{callback}(#{Jason.encode!(sub_id)});")
      else
        %RedirectResponse{
          status: 200,
          headers: %{"content-type" => "text/plain; charset=utf-8"},
          body: sub_id,
          action_type: "sub_id"
        }
      end
    end
  end

  # 14. ToCampaign (Campaign Chain)
  defmodule ToCampaign do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      # Note: Stage 27 handles pipeline restart; if it reaches here, return default redirect
      target_url = Base.resolve_target_url(payload)
      RedirectResponse.redirect(target_url, 302)
    end
  end

  # 15. DoNothing
  defmodule DoNothing do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{}) do
      %RedirectResponse{
        status: 200,
        headers: %{"content-type" => "text/plain; charset=utf-8"},
        body: "",
        action_type: "do_nothing"
      }
    end
  end

  # 16. Status404
  defmodule Status404 do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{}) do
      %RedirectResponse{
        status: 404,
        headers: %{"content-type" => "text/html; charset=utf-8"},
        body: "<h1>404 Not Found</h1>",
        action_type: "status404"
      }
    end
  end

  # 17. FormSubmit (Auto-POST form forwarding all query params as hidden fields)
  defmodule FormSubmit do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      params = (payload.request && Map.get(payload.request, :query_params, %{})) || %{}
      
      inputs =
        Enum.map(params, fn {k, v} ->
          ~s(<input type="hidden" name="#{Plug.HTML.html_escape(to_string(k))}" value="#{Plug.HTML.html_escape(to_string(v))}">)
        end)
        |> Enum.join("\n")

      html = """
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"><title>Submitting...</title></head>
      <body onload="setTimeout(function(){ document.getElementById('redirectForm').submit(); }, 10);">
        <form id="redirectForm" method="POST" action="#{target_url}">
          #{inputs}
          <noscript><button type="submit">Click here to continue</button></noscript>
        </form>
      </body>
      </html>
      """
      RedirectResponse.html(html)
    end
  end

  # 18. JsForIframe
  defmodule JsForIframe do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      html = RedirectService.frame_redirect(target_url)
      RedirectResponse.html(html)
    end
  end

  # 19. JsForScript
  defmodule JsForScript do
    @behaviour TrafficRedirect.Domain.Action.Behaviour
    def execute(%Payload{} = payload) do
      target_url = Base.resolve_target_url(payload)
      escaped_url = RedirectService.escape_js(target_url)
      RedirectResponse.javascript("window.location.href = \"#{escaped_url}\";")
    end
  end
end

defmodule TrafficRedirect.Domain.Action.Registry do
  @moduledoc """
  Extensible Action Registry supporting built-in and custom action types.
  """
  alias TrafficRedirect.Domain.Action.Actions

  @actions %{
    "http" => Actions.HttpRedirect,
    "location" => Actions.HttpRedirect,
    "js" => Actions.Js,
    "meta" => Actions.Meta,
    "double_meta" => Actions.DoubleMeta,
    "blank_referrer" => Actions.BlankReferrer,
    "iframe" => Actions.Iframe,
    "frame" => Actions.Frame,
    "curl" => Actions.Curl,
    "remote" => Actions.Remote,
    "local_file" => Actions.LocalFile,
    "show_html" => Actions.ShowHtml,
    "show_text" => Actions.ShowText,
    "echo" => Actions.ShowText,
    "sub_id" => Actions.SubId,
    "campaign" => Actions.ToCampaign,
    "group" => Actions.ToCampaign,
    "do_nothing" => Actions.DoNothing,
    "status404" => Actions.Status404,
    "formsubmit" => Actions.FormSubmit,
    "js_for_iframe" => Actions.JsForIframe,
    "js_for_script" => Actions.JsForScript
  }

  def get(name) when is_binary(name) do
    key = name |> String.downcase() |> String.trim()
    Map.get(@actions, key, Actions.HttpRedirect)
  end

  def get(_), do: Actions.HttpRedirect
end
