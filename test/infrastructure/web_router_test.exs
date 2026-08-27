defmodule TrafficRedirect.Infrastructure.WebRouterTest do
  use ExUnit.Case, async: true
  import Plug.Test
  alias TrafficRedirect.Domain.Model.Campaign
  alias TrafficRedirect.Infrastructure.Adapters.Storage.MemoryCampaignRepo
  alias TrafficRedirect.Infrastructure.Web.Endpoint

  @opts Endpoint.init([])

  setup do
    campaign = %Campaign{
      id: "1",
      alias: "test_campaign",
      name: "Test Campaign"
    }
    MemoryCampaignRepo.save(campaign)
    :ok
  end

  # Route 1: Postback
  test "POST /{key}/postback and GET /postback?sub_id=..." do
    conn_path = conn(:post, "/lead123/postback?payout=10.0&status=sale") |> Endpoint.call(@opts)
    assert conn_path.status == 200
    assert conn_path.resp_body =~ "success"

    conn_query = conn(:get, "/postback?sub_id=lead456&payout=15.0") |> Endpoint.call(@opts)
    assert conn_query.status == 200
    assert conn_query.resp_body =~ "success"
  end

  # Route 2: Ping
  test "GET /ping returns pong" do
    conn = conn(:get, "/ping") |> Endpoint.call(@opts)
    assert conn.status == 200
    assert conn.resp_body == "pong"
  end

  # Route 3: Preview
  test "GET /preview returns preview HTML" do
    conn = conn(:get, "/preview") |> Endpoint.call(@opts)
    assert conn.status == 200
    assert conn.resp_body =~ "Landing Preview Mode"
  end

  # Route 4: License Refresh
  test "GET /license/refresh returns valid license json" do
    conn = conn(:get, "/license/refresh") |> Endpoint.call(@opts)
    assert conn.status == 200
    assert conn.resp_body =~ "Enterprise"
  end

  # Route 5: Click API v1-v4 and /api.php
  test "GET /click_api/v1 and /api.php return JSON" do
    conn_v1 = conn(:get, "/click_api/v1?k_router_campaign=test_campaign") |> Endpoint.call(@opts)
    assert conn_v1.status == 200
    assert conn_v1.resp_body =~ "success"

    conn_api = conn(:get, "/api.php?k_router_campaign=test_campaign") |> Endpoint.call(@opts)
    assert conn_api.status == 200
    assert conn_api.resp_body =~ "success"
  end

  # Route 6: LandingOfferHandler (?return=)
  test "GET /?return=1 executes landing offer redirect" do
    conn = conn(:get, "/test_campaign?return=1") |> Endpoint.call(@opts)
    assert conn.status in [200, 302]
  end

  # Route 7 & 8: JS Tracker Script & Second Encounter
  test "GET /test_campaign?tracker=1 returns IIFE tracker script" do
    conn = conn(:get, "/test_campaign?tracker=1") |> Endpoint.call(@opts)
    assert conn.status == 200
    assert conn.resp_body =~ "(function(window, document)"
  end

  # Route 10: /favicon.ico -> 404
  test "GET /favicon.ico returns 404" do
    conn = conn(:get, "/favicon.ico") |> Endpoint.call(@opts)
    assert conn.status == 404
  end

  # Route 11: /robots.txt
  test "GET /robots.txt returns robots disallow" do
    conn = conn(:get, "/robots.txt") |> Endpoint.call(@opts)
    assert conn.status == 200
    assert conn.resp_body =~ "Disallow: /"
  end

  # Route 12: Main Click /{alias} -> 302 Redirect
  test "GET /test_campaign redirects visitor" do
    conn = conn(:get, "/test_campaign?source=fb&keyword=sneakers") |> Endpoint.call(@opts)
    assert conn.status == 302
    assert conn.resp_headers |> Enum.any?(fn {k, _v} -> k == "location" end)
    assert conn.resp_headers |> Enum.any?(fn {k, _v} -> k == "content-length" end)
    assert conn.resp_headers |> Enum.any?(fn {k, _v} -> k == "server" end)
  end

  # Route 13: Unknown campaign -> 404
  test "GET /non_existent_campaign returns 404" do
    conn = conn(:get, "/non_existent_campaign") |> Endpoint.call(@opts)
    assert conn.status == 404
  end
end
