defmodule TrafficRedirect.Domain.Filter.Behaviour do
  @moduledoc """
  Filter behaviour (Specification Pattern) for evaluating stream criteria against RawClick.
  """
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  @callback match?(filter :: StreamFilter.t(), click :: RawClick.t(), context :: map()) :: boolean()
end

defmodule TrafficRedirect.Domain.Filter.Helpers do
  @moduledoc false

  @doc """
  Evaluates mode against expected values and actual value.
  Modes: :is, :is_not, :in, :not_in, :greater, :less, :regex
  """
  def compare(mode, expected, actual) do
    actual_str = to_string(actual || "") |> String.trim() |> String.downcase()

    case mode do
      :is ->
        expected_str = to_string(expected) |> String.trim() |> String.downcase()
        actual_str == expected_str

      :is_not ->
        expected_str = to_string(expected) |> String.trim() |> String.downcase()
        actual_str != expected_str

      :in ->
        list = normalize_list(expected)
        Enum.any?(list, &(String.downcase(to_string(&1)) == actual_str))

      :not_in ->
        list = normalize_list(expected)
        Enum.all?(list, &(String.downcase(to_string(&1)) != actual_str))

      :contains ->
        expected_str = to_string(expected) |> String.trim() |> String.downcase()
        String.contains?(actual_str, expected_str)

      :regex ->
        pattern = to_string(expected)
        case Regex.compile(pattern, "i") do
          {:ok, regex} -> Regex.match?(regex, actual_str)
          _ -> false
        end

      :greater ->
        parse_float(actual) > parse_float(expected)

      :less ->
        parse_float(actual) < parse_float(expected)

      _ ->
        true
    end
  end

  defp normalize_list(list) when is_list(list), do: list
  defp normalize_list(str) when is_binary(str), do: String.split(str, ~r/[,\n\r]+/, trim: true)
  defp normalize_list(other), do: [other]

  defp parse_float(val) when is_number(val), do: val * 1.0
  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(_), do: 0.0
end

defmodule TrafficRedirect.Domain.Filter.Filters do
  @moduledoc """
  Catalog of 26 built-in filters matching the Traffic Redirect specification.
  """
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}
  import TrafficRedirect.Domain.Filter.Helpers

  # 1. AnyParam
  defmodule AnyParam do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{} = click, _ctx) do
      all_params = Map.merge(click.custom_params || %{}, click.sub_ids || %{})
      Enum.any?(all_params, fn {_k, v} -> compare(mode, payload, v) end)
    end
  end

  # 2. Browser
  defmodule Browser do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{browser: browser}, _ctx) do
      compare(mode, payload, browser)
    end
  end

  # 3. BrowserVersion
  defmodule BrowserVersion do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{browser_version: ver}, _ctx) do
      compare(mode, payload, ver)
    end
  end

  # 4. City
  defmodule City do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{city: city}, _ctx) do
      compare(mode, payload, city)
    end
  end

  # 5. ConnectionType
  defmodule ConnectionType do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{connection_type: ct}, _ctx) do
      compare(mode, payload, ct)
    end
  end

  # 6. Country
  defmodule Country do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{country: country}, _ctx) do
      compare(mode, payload, country)
    end
  end

  # 7. DeviceModel
  defmodule DeviceModel do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{device_model: dm}, _ctx) do
      compare(mode, payload, dm)
    end
  end

  # 8. DeviceType
  defmodule DeviceType do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{device_type: dt}, _ctx) do
      compare(mode, payload, dt)
    end
  end

  # 9. EmptyReferrer
  defmodule EmptyReferrer do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{payload: payload}, %RawClick{referrer: ref}, _ctx) do
      is_empty = is_nil(ref) or String.trim(ref) == ""
      expected = payload in [true, "true", "1", 1]
      is_empty == expected
    end
  end

  # 10. Interval
  defmodule Interval do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{options: options}, _click, _ctx) do
      now = Time.utc_now()
      start_time = Map.get(options, :start_time, ~T[00:00:00])
      end_time = Map.get(options, :end_time, ~T[23:59:59])
      Time.compare(now, start_time) in [:gt, :eq] and Time.compare(now, end_time) in [:lt, :eq]
    end
  end

  # 11. Ip
  defmodule Ip do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{} = click, _ctx) do
      ip = click.real_remote_ip || click.ip
      compare(mode, payload, ip)
    end
  end

  # 12. Ipv6
  defmodule Ipv6 do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{payload: payload}, %RawClick{ipv6: ipv6}, _ctx) do
      has_ipv6 = not is_nil(ipv6) and String.contains?(to_string(ipv6), ":")
      expected = payload in [true, "true", "1", 1]
      has_ipv6 == expected
    end
  end

  # 13. IsBot
  defmodule IsBot do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{payload: payload}, %RawClick{is_bot: is_bot}, _ctx) do
      expected = payload in [true, "true", "1", 1]
      is_bot == expected
    end
  end

  # 14. Isp
  defmodule Isp do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{isp: isp}, _ctx) do
      compare(mode, payload, isp)
    end
  end

  # 15. Language
  defmodule Language do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{language: lang}, _ctx) do
      compare(mode, payload, lang)
    end
  end

  # 16. Limit
  defmodule Limit do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{options: options}, _click, context) do
      limit = Map.get(options, :limit, 0)
      current_count = Map.get(context, :stream_hit_count, 0)
      limit == 0 or current_count < limit
    end
  end

  # 17. Operator
  defmodule Operator do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{operator: op}, _ctx) do
      compare(mode, payload, op)
    end
  end

  # 18. Os
  defmodule Os do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{os: os}, _ctx) do
      compare(mode, payload, os)
    end
  end

  # 19. OsVersion
  defmodule OsVersion do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{os_version: osv}, _ctx) do
      compare(mode, payload, osv)
    end
  end

  # 20. Parameter
  defmodule Parameter do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload, options: opts}, %RawClick{} = click, _ctx) do
      param_name = Map.get(opts, :param_name) || Map.get(opts, "param_name")
      if is_nil(param_name) do
        true
      else
        val = Map.get(click.custom_params || %{}, param_name)
        compare(mode, payload, val)
      end
    end
  end

  # 21. Proxy
  defmodule Proxy do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{payload: payload}, %RawClick{is_proxy: is_proxy}, _ctx) do
      expected = payload in [true, "true", "1", 1]
      is_proxy == expected
    end
  end

  # 22. Referrer
  defmodule Referrer do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{referrer: ref}, _ctx) do
      compare(mode, payload, ref)
    end
  end

  # 23. Region
  defmodule Region do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{region: region}, _ctx) do
      compare(mode, payload, region)
    end
  end

  # 24. Schedule
  defmodule Schedule do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{options: options}, _click, _ctx) do
      now = DateTime.utc_now()
      day_of_week = Date.day_of_week(DateTime.to_date(now)) # 1 (Mon) .. 7 (Sun)
      hour = now.hour # 0 .. 23
      allowed_days = Map.get(options, :days, [1, 2, 3, 4, 5, 6, 7])
      allowed_hours = Map.get(options, :hours, Enum.to_list(0..23))
      day_of_week in allowed_days and hour in allowed_hours
    end
  end

  # 25. Uniqueness
  defmodule Uniqueness do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{payload: payload}, %RawClick{is_unique_stream: is_unique}, _ctx) do
      expected = payload in [true, "true", "1", 1]
      is_unique == expected
    end
  end

  # 26. UserAgent
  defmodule UserAgent do
    @behaviour TrafficRedirect.Domain.Filter.Behaviour
    def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{user_agent: ua}, _ctx) do
      compare(mode, payload, ua)
    end
  end
end

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

defmodule TrafficRedirect.Domain.Filter.Checker do
  @moduledoc """
  StreamFiltersChecker evaluates a Stream's list of filters against a RawClick.
  Supports filter_or: AND (any failure -> reject) vs OR (any success -> pass).
  If a stream has no filters, it automatically passes.
  """
  alias TrafficRedirect.Domain.Filter.Registry
  alias TrafficRedirect.Domain.Model.{RawClick, Stream}

  @doc """
  Returns true if the stream passes all filter conditions for the given click.
  """
  def passes?(%Stream{filters: filters, filter_or: filter_or}, %RawClick{} = click, context \\ %{}) do
    case filters do
      nil ->
        true

      [] ->
        true

      filter_list ->
        if filter_or do
          # OR mode: pass if at least one filter matches
          Enum.any?(filter_list, fn filter -> evaluate_filter(filter, click, context) end)
        else
          # AND mode: pass if ALL filters match
          Enum.all?(filter_list, fn filter -> evaluate_filter(filter, click, context) end)
        end
    end
  end

  defp evaluate_filter(filter, click, context) do
    case Registry.get(filter.name) do
      nil ->
        # Unknown filter: default to pass to avoid breaking traffic
        true

      module ->
        module.match?(filter, click, context)
    end
  end
end
