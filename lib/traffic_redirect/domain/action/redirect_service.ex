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
