defmodule TrafficRedirect.Infrastructure.Adapters.Detectors.GeoService do
  @moduledoc """
  GeoIP resolution adapter.
  """
  @behaviour TrafficRedirect.Application.Ports.Outbound.GeoServicePort

  def lookup(ip) when is_binary(ip) do
    # Default fallback / mock resolution
    cond do
      ip in ["127.0.0.1", "::1"] ->
        %{country: "US", region: "CA", city: "Localhost", isp: "Local", operator: "None", connection_type: "broadband"}

      String.starts_with?(ip, "192.168.") or String.starts_with?(ip, "10.") ->
        %{country: "US", region: "CA", city: "Private", isp: "Private", operator: "None", connection_type: "broadband"}

      true ->
        %{country: "US", region: "CA", city: "San Francisco", isp: "Cloudflare", operator: "None", connection_type: "broadband"}
    end
  end

  def lookup(_), do: %{country: "US", region: "", city: "", isp: "", operator: "", connection_type: ""}
end

defmodule TrafficRedirect.Infrastructure.Adapters.Detectors.DeviceDetector do
  @moduledoc """
  User-Agent parser and device resolution adapter.
  """
  @behaviour TrafficRedirect.Application.Ports.Outbound.DeviceDetectorPort

  def detect(ua) when is_binary(ua) do
    ua_lower = String.downcase(ua)

    {device_type, device_model} =
      cond do
        String.contains?(ua_lower, "ipad") ->
          {:tablet, "iPad"}

        String.contains?(ua_lower, "iphone") ->
          {:mobile, "iPhone"}

        String.contains?(ua_lower, "android") and String.contains?(ua_lower, "mobile") ->
          {:mobile, "Android Device"}

        String.contains?(ua_lower, "android") ->
          {:tablet, "Android Tablet"}

        true ->
          {:desktop, "Desktop"}
      end

    {os, os_version} =
      cond do
        String.contains?(ua_lower, "mac os x") ->
          {"macOS", "14.0"}

        String.contains?(ua_lower, "windows") ->
          {"Windows", "11"}

        String.contains?(ua_lower, "iphone os") ->
          {"iOS", "17.0"}

        String.contains?(ua_lower, "android") ->
          {"Android", "14"}

        String.contains?(ua_lower, "linux") ->
          {"Linux", "1.0"}

        true ->
          {"Unknown", ""}
      end

    {browser, browser_version} =
      cond do
        String.contains?(ua_lower, "edg") ->
          {"Edge", "120"}

        String.contains?(ua_lower, "chrome") ->
          {"Chrome", "125"}

        String.contains?(ua_lower, "safari") and not String.contains?(ua_lower, "chrome") ->
          {"Safari", "17"}

        String.contains?(ua_lower, "firefox") ->
          {"Firefox", "126"}

        true ->
          {"Other", ""}
      end

    %{
      device_type: device_type,
      device_model: device_model,
      os: os,
      os_version: os_version,
      browser: browser,
      browser_version: browser_version
    }
  end

  def detect(_), do: %{device_type: :desktop, device_model: "", os: "Unknown", os_version: "", browser: "Unknown", browser_version: ""}
end

defmodule TrafficRedirect.Infrastructure.Adapters.Detectors.BotDetector do
  @moduledoc """
  Bot and Proxy detection heuristics adapter.
  """
  @behaviour TrafficRedirect.Application.Ports.Outbound.BotDetectorPort

  @bot_signatures [
    "googlebot", "bingbot", "yandex", "baiduspider", "facebookexternalhit",
    "twitterbot", "rogerbot", "linkedinbot", "embedly", "quora link preview",
    "showyoubot", "outbrain", "pinterest", "slackbot", "vkshare", "w3c_validator",
    "ahrefsbot", "semrushbot", "dotbot", "mj12bot", "curl", "python-requests"
  ]

  def detect(ua, _ip, headers) do
    ua_lower = String.downcase(ua || "")
    is_bot_ua = Enum.any?(@bot_signatures, fn sig -> String.contains?(ua_lower, sig) end)
    
    # Proxy detection by headers
    has_via = Map.has_key?(headers || %{}, "via")
    has_proxy = Map.has_key?(headers || %{}, "x-forwarded-server")

    %{
      is_bot: is_bot_ua,
      is_proxy: has_via or has_proxy
    }
  end
end
