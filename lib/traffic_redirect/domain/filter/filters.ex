# 1. AnyParam
defmodule TrafficRedirect.Domain.Filter.Filters.AnyParam do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{} = click, _ctx) do
    all_params = Map.merge(click.custom_params || %{}, click.sub_ids || %{})
    Enum.any?(all_params, fn {_k, v} -> Helpers.compare(mode, payload, v) end)
  end
end

# 2. Browser
defmodule TrafficRedirect.Domain.Filter.Filters.Browser do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{browser: browser}, _ctx) do
    Helpers.compare(mode, payload, browser)
  end
end

# 3. BrowserVersion
defmodule TrafficRedirect.Domain.Filter.Filters.BrowserVersion do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{browser_version: ver}, _ctx) do
    Helpers.compare(mode, payload, ver)
  end
end

# 4. City
defmodule TrafficRedirect.Domain.Filter.Filters.City do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{city: city}, _ctx) do
    Helpers.compare(mode, payload, city)
  end
end

# 5. ConnectionType
defmodule TrafficRedirect.Domain.Filter.Filters.ConnectionType do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{connection_type: ct}, _ctx) do
    Helpers.compare(mode, payload, ct)
  end
end

# 6. Country
defmodule TrafficRedirect.Domain.Filter.Filters.Country do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{country: country}, _ctx) do
    Helpers.compare(mode, payload, country)
  end
end

# 7. DeviceModel
defmodule TrafficRedirect.Domain.Filter.Filters.DeviceModel do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{device_model: dm}, _ctx) do
    Helpers.compare(mode, payload, dm)
  end
end

# 8. DeviceType
defmodule TrafficRedirect.Domain.Filter.Filters.DeviceType do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{device_type: dt}, _ctx) do
    Helpers.compare(mode, payload, dt)
  end
end

# 9. EmptyReferrer
defmodule TrafficRedirect.Domain.Filter.Filters.EmptyReferrer do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{payload: payload}, %RawClick{referrer: ref}, _ctx) do
    is_empty = is_nil(ref) or String.trim(ref) == ""
    expected = payload in [true, "true", "1", 1]
    is_empty == expected
  end
end

# 10. Interval
defmodule TrafficRedirect.Domain.Filter.Filters.Interval do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Model.StreamFilter

  def match?(%StreamFilter{options: options}, _click, _ctx) do
    now = Time.utc_now()
    start_time = Map.get(options, :start_time, ~T[00:00:00])
    end_time = Map.get(options, :end_time, ~T[23:59:59])
    Time.compare(now, start_time) in [:gt, :eq] and Time.compare(now, end_time) in [:lt, :eq]
  end
end

# 11. Ip
defmodule TrafficRedirect.Domain.Filter.Filters.Ip do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{} = click, _ctx) do
    ip = click.real_remote_ip || click.ip
    Helpers.compare(mode, payload, ip)
  end
end

# 12. Ipv6
defmodule TrafficRedirect.Domain.Filter.Filters.Ipv6 do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{payload: payload}, %RawClick{ipv6: ipv6}, _ctx) do
    has_ipv6 = not is_nil(ipv6) and String.contains?(to_string(ipv6), ":")
    expected = payload in [true, "true", "1", 1]
    has_ipv6 == expected
  end
end

# 13. IsBot
defmodule TrafficRedirect.Domain.Filter.Filters.IsBot do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{payload: payload}, %RawClick{is_bot: is_bot}, _ctx) do
    expected = payload in [true, "true", "1", 1]
    is_bot == expected
  end
end

# 14. Isp
defmodule TrafficRedirect.Domain.Filter.Filters.Isp do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{isp: isp}, _ctx) do
    Helpers.compare(mode, payload, isp)
  end
end

# 15. Language
defmodule TrafficRedirect.Domain.Filter.Filters.Language do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{language: lang}, _ctx) do
    Helpers.compare(mode, payload, lang)
  end
end

# 16. Limit
defmodule TrafficRedirect.Domain.Filter.Filters.Limit do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Model.StreamFilter

  def match?(%StreamFilter{options: options}, _click, context) do
    limit = Map.get(options, :limit, 0)
    current_count = Map.get(context, :stream_hit_count, 0)
    limit == 0 or current_count < limit
  end
end

# 17. Operator
defmodule TrafficRedirect.Domain.Filter.Filters.Operator do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{operator: op}, _ctx) do
    Helpers.compare(mode, payload, op)
  end
end

# 18. Os
defmodule TrafficRedirect.Domain.Filter.Filters.Os do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{os: os}, _ctx) do
    Helpers.compare(mode, payload, os)
  end
end

# 19. OsVersion
defmodule TrafficRedirect.Domain.Filter.Filters.OsVersion do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{os_version: osv}, _ctx) do
    Helpers.compare(mode, payload, osv)
  end
end

# 20. Parameter
defmodule TrafficRedirect.Domain.Filter.Filters.Parameter do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload, options: opts}, %RawClick{} = click, _ctx) do
    param_name = Map.get(opts, :param_name) || Map.get(opts, "param_name")
    if is_nil(param_name) do
      true
    else
      val = Map.get(click.custom_params || %{}, param_name)
      Helpers.compare(mode, payload, val)
    end
  end
end

# 21. Proxy
defmodule TrafficRedirect.Domain.Filter.Filters.Proxy do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{payload: payload}, %RawClick{is_proxy: is_proxy}, _ctx) do
    expected = payload in [true, "true", "1", 1]
    is_proxy == expected
  end
end

# 22. Referrer
defmodule TrafficRedirect.Domain.Filter.Filters.Referrer do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{referrer: ref}, _ctx) do
    Helpers.compare(mode, payload, ref)
  end
end

# 23. Region
defmodule TrafficRedirect.Domain.Filter.Filters.Region do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{region: region}, _ctx) do
    Helpers.compare(mode, payload, region)
  end
end

# 24. Schedule
defmodule TrafficRedirect.Domain.Filter.Filters.Schedule do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Model.StreamFilter

  def match?(%StreamFilter{options: options}, _click, _ctx) do
    now = DateTime.utc_now()
    day_of_week = Date.day_of_week(DateTime.to_date(now))
    hour = now.hour
    allowed_days = Map.get(options, :days, [1, 2, 3, 4, 5, 6, 7])
    allowed_hours = Map.get(options, :hours, Enum.to_list(0..23))
    day_of_week in allowed_days and hour in allowed_hours
  end
end

# 25. Uniqueness
defmodule TrafficRedirect.Domain.Filter.Filters.Uniqueness do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{payload: payload}, %RawClick{is_unique_stream: is_unique}, _ctx) do
    expected = payload in [true, "true", "1", 1]
    is_unique == expected
  end
end

# 26. UserAgent
defmodule TrafficRedirect.Domain.Filter.Filters.UserAgent do
  @behaviour TrafficRedirect.Domain.Filter.Behaviour
  alias TrafficRedirect.Domain.Filter.Helpers
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  def match?(%StreamFilter{mode: mode, payload: payload}, %RawClick{user_agent: ua}, _ctx) do
    Helpers.compare(mode, payload, ua)
  end
end
