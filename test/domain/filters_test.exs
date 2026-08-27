defmodule TrafficRedirect.Domain.FiltersTest do
  use ExUnit.Case, async: true
  alias TrafficRedirect.Domain.Filter.Checker
  alias TrafficRedirect.Domain.Model.{RawClick, Stream, StreamFilter}

  test "Geo and Device Filters match accurately" do
    click = %RawClick{
      country: "US",
      city: "New York",
      device_type: :mobile,
      os: "iOS",
      browser: "Safari",
      real_remote_ip: "192.168.1.100"
    }

    # Country filter
    f_country = %StreamFilter{name: "country", mode: :in, payload: ["US", "CA", "GB"]}
    stream = %Stream{id: "1", campaign_id: "1", filters: [f_country], filter_or: false}
    assert Checker.passes?(stream, click)

    # Country negative filter
    f_country_not = %StreamFilter{name: "country", mode: :in, payload: ["DE", "FR"]}
    stream_not = %Stream{id: "1", campaign_id: "1", filters: [f_country_not], filter_or: false}
    refute Checker.passes?(stream_not, click)

    # Device type filter
    f_device = %StreamFilter{name: "device_type", mode: :is, payload: "mobile"}
    assert Checker.passes?(%Stream{id: "1", campaign_id: "1", filters: [f_device]}, click)

    # OS filter
    f_os = %StreamFilter{name: "os", mode: :is, payload: "iOS"}
    assert Checker.passes?(%Stream{id: "1", campaign_id: "1", filters: [f_os]}, click)
  end

  test "Bot and Proxy filters" do
    bot_click = %RawClick{is_bot: true, is_proxy: false}
    human_click = %RawClick{is_bot: false, is_proxy: false}

    f_bot = %StreamFilter{name: "is_bot", payload: false}
    stream = %Stream{id: "1", campaign_id: "1", filters: [f_bot]}

    refute Checker.passes?(stream, bot_click)
    assert Checker.passes?(stream, human_click)
  end

  test "Filter AND vs OR logic" do
    click = %RawClick{country: "US", os: "Android"}

    f1 = %StreamFilter{name: "country", mode: :is, payload: "US"}
    f2 = %StreamFilter{name: "os", mode: :is, payload: "iOS"} # Fails

    # AND mode (filter_or: false) -> should fail
    stream_and = %Stream{id: "1", campaign_id: "1", filters: [f1, f2], filter_or: false}
    refute Checker.passes?(stream_and, click)

    # OR mode (filter_or: true) -> should pass because country matches
    stream_or = %Stream{id: "1", campaign_id: "1", filters: [f1, f2], filter_or: true}
    assert Checker.passes?(stream_or, click)
  end

  test "Uniqueness filter" do
    first_hit = %RawClick{is_unique_stream: true}
    repeat_hit = %RawClick{is_unique_stream: false}

    f_unique = %StreamFilter{name: "uniqueness", payload: true}
    stream = %Stream{id: "1", campaign_id: "1", filters: [f_unique]}

    assert Checker.passes?(stream, first_hit)
    refute Checker.passes?(stream, repeat_hit)
  end

  test "Stream with empty filters passes automatically" do
    click = %RawClick{}
    stream = %Stream{id: "1", campaign_id: "1", filters: []}
    assert Checker.passes?(stream, click)
  end
end
