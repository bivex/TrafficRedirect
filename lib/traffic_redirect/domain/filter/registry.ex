defmodule TrafficRedirect.Domain.Filter.Registry do
  @moduledoc """
  Extensible Registry of Stream Filters.
  """
  alias TrafficRedirect.Domain.Filter.Filters

  @filter_map %{
    "anyparam" => Filters.AnyParam,
    "browser" => Filters.Browser,
    "browserversion" => Filters.BrowserVersion,
    "city" => Filters.City,
    "connectiontype" => Filters.ConnectionType,
    "country" => Filters.Country,
    "devicemodel" => Filters.DeviceModel,
    "devicetype" => Filters.DeviceType,
    "emptyreferrer" => Filters.EmptyReferrer,
    "interval" => Filters.Interval,
    "ip" => Filters.Ip,
    "ipv6" => Filters.Ipv6,
    "isbot" => Filters.IsBot,
    "isp" => Filters.Isp,
    "language" => Filters.Language,
    "limit" => Filters.Limit,
    "operator" => Filters.Operator,
    "os" => Filters.Os,
    "osversion" => Filters.OsVersion,
    "parameter" => Filters.Parameter,
    "proxy" => Filters.Proxy,
    "referrer" => Filters.Referrer,
    "region" => Filters.Region,
    "schedule" => Filters.Schedule,
    "uniqueness" => Filters.Uniqueness,
    "useragent" => Filters.UserAgent
  }

  def get(name) when is_binary(name) do
    key = name |> String.downcase() |> String.replace("_", "")
    Map.get(@filter_map, key)
  end

  def get(_), do: nil
end
