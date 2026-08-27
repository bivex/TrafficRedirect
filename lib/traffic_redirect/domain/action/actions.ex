# 1. HttpRedirect
defmodule TrafficRedirect.Domain.Action.Actions.HttpRedirect do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.{BaseHelper, RedirectService}
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{context: :script} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    js_code = "window.location.href = '#{RedirectService.escape_js(target_url)}';"
    RedirectResponse.javascript(js_code)
  end

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    RedirectResponse.redirect(target_url, 302)
  end
end

# 2. Js
defmodule TrafficRedirect.Domain.Action.Actions.Js do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.{BaseHelper, RedirectService}
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{context: :script} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    RedirectResponse.javascript("window.top.location.href = '#{RedirectService.escape_js(target_url)}';")
  end

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    html = RedirectService.script_redirect(target_url)
    RedirectResponse.html(html)
  end
end

# 3. Meta
defmodule TrafficRedirect.Domain.Action.Actions.Meta do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.{BaseHelper, RedirectService}
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    delay = Map.get(payload.action_options || %{}, :delay, 0)
    html = RedirectService.meta_redirect(target_url, %{delay: delay})
    RedirectResponse.html(html)
  end
end

# 4. DoubleMeta
defmodule TrafficRedirect.Domain.Action.Actions.DoubleMeta do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.BaseHelper
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    ua = payload.raw_click && (payload.raw_click.user_agent || "unknown")

    secret = Application.get_env(:traffic_redirect, :gateway_secret, "traffic_redirect_secret_key_2026")
    derived_key = :crypto.mac(:hmac, :sha256, secret, ua)

    claims = %{
      "url" => target_url,
      "exp" => System.os_time(:second) + 120,
      "iat" => System.os_time(:second)
    }

    header_b64 = Base.url_encode64(Jason.encode!(%{"alg" => "HS256", "typ" => "JWT"}), padding: false)
    payload_b64 = Base.url_encode64(Jason.encode!(claims), padding: false)
    signing_input = "#{header_b64}.#{payload_b64}"
    sig_b64 = Base.url_encode64(:crypto.mac(:hmac, :sha256, derived_key, signing_input), padding: false)
    token = "#{signing_input}.#{sig_b64}"

    gateway_url = "/gateway.php?frm=dm&token=#{token}"
    RedirectResponse.redirect(gateway_url, 302)
  end
end

# 5. BlankReferrer
defmodule TrafficRedirect.Domain.Action.Actions.BlankReferrer do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.{BaseHelper, RedirectService}
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    html = RedirectService.meta_redirect(target_url, %{delay: 0, no_referrer: true})
    RedirectResponse.html(html)
  end
end

# 6. Iframe
defmodule TrafficRedirect.Domain.Action.Actions.Iframe do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.BaseHelper
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{context: :frame} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    RedirectResponse.redirect(target_url, 302)
  end

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
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

# 7. Frame
defmodule TrafficRedirect.Domain.Action.Actions.Frame do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.BaseHelper
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
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

# 8. Curl
defmodule TrafficRedirect.Domain.Action.Actions.Curl do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.BaseHelper
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)

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
defmodule TrafficRedirect.Domain.Action.Actions.Remote do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.Actions.HttpRedirect
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{} = payload) do
    HttpRedirect.execute(payload)
  end
end

# 10. LocalFile
defmodule TrafficRedirect.Domain.Action.Actions.LocalFile do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{landing: landing} = payload) do
    local_path = (landing && landing.local_path) || "priv/landings/default/index.html"

    content =
      if File.exists?(local_path) do
        File.read!(local_path)
      else
        "<!DOCTYPE html><html><body><h1>Landing Page</h1></body></html>"
      end

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
defmodule TrafficRedirect.Domain.Action.Actions.ShowHtml do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Macro.Processor
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{context: :script} = payload) do
    html = Processor.process(to_string(payload.action_payload || ""), payload)
    RedirectResponse.javascript("document.write(#{Jason.encode!(html)});")
  end

  def execute(%Payload{} = payload) do
    html = Processor.process(to_string(payload.action_payload || ""), payload)
    RedirectResponse.html(html)
  end
end

# 12. ShowText
defmodule TrafficRedirect.Domain.Action.Actions.ShowText do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Macro.Processor
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

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

# 13. SubId
defmodule TrafficRedirect.Domain.Action.Actions.SubId do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

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

# 14. ToCampaign
defmodule TrafficRedirect.Domain.Action.Actions.ToCampaign do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.Actions.HttpRedirect
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{} = payload) do
    HttpRedirect.execute(payload)
  end
end

# 15. DoNothing
defmodule TrafficRedirect.Domain.Action.Actions.DoNothing do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

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
defmodule TrafficRedirect.Domain.Action.Actions.Status404 do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{}) do
    %RedirectResponse{
      status: 404,
      headers: %{"content-type" => "text/html; charset=utf-8"},
      body: "<h1>404 Not Found</h1>",
      action_type: "status404"
    }
  end
end

# 17. FormSubmit
defmodule TrafficRedirect.Domain.Action.Actions.FormSubmit do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.BaseHelper
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
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
defmodule TrafficRedirect.Domain.Action.Actions.JsForIframe do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.{BaseHelper, RedirectService}
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    html = RedirectService.frame_redirect(target_url)
    RedirectResponse.html(html)
  end
end

# 19. JsForScript
defmodule TrafficRedirect.Domain.Action.Actions.JsForScript do
  @behaviour TrafficRedirect.Domain.Action.Behaviour
  alias TrafficRedirect.Domain.Action.{BaseHelper, RedirectService}
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{} = payload) do
    target_url = BaseHelper.resolve_target_url(payload)
    escaped_url = RedirectService.escape_js(target_url)
    RedirectResponse.javascript("window.location.href = \"#{escaped_url}\";")
  end
end
