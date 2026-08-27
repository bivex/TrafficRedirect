defmodule TrafficRedirect.Application.ServicesTest do
  use ExUnit.Case, async: false
  alias TrafficRedirect.Application.Services.{
    ClickApiService,
    ClickService,
    PostbackService,
    TrackerScriptService
  }
  alias TrafficRedirect.Domain.Model.Campaign
  alias TrafficRedirect.Infrastructure.Adapters.Storage.MemoryCampaignRepo

  setup do
    # Ensure test campaign is seeded in ETS
    campaign = %Campaign{
      id: "99",
      alias: "app_test_camp",
      name: "Application Test Campaign",
      cost_default: 0.10
    }
    MemoryCampaignRepo.save(campaign)
    :ok
  end

  test "ClickService handles full click request" do
    req = %{
      query_params: %{"k_router_campaign" => "app_test_camp", "source" => "google"},
      headers: %{"user-agent" => "Mozilla/5.0", "x-forwarded-for" => "8.8.8.8"},
      host: "redirect.com"
    }

    {:ok, resp} = ClickService.process_click(req)
    assert resp.status in [302, 200]
  end

  test "ClickApiService handles server-to-server click and returns JSON response" do
    req = %{
      query_params: %{"k_router_campaign" => "app_test_camp", "cost" => "0.50"},
      headers: %{"user-agent" => "API-Client/1.0"}
    }

    {:ok, resp} = ClickApiService.process_click_api(1, req)
    assert resp.status == 200
    assert resp.headers["content-type"] =~ "application/json"
    
    decoded = Jason.decode!(resp.body)
    assert decoded["status"] == "success"
    assert is_binary(decoded["sub_id"])
  end

  test "PostbackService validates and records conversion" do
    params = %{
      "sub_id" => "click_abc_123",
      "token" => "tok_xyz",
      "payout" => "45.00",
      "currency" => "USD",
      "status" => "sale"
    }

    {:ok, conv} = PostbackService.process_postback(params)
    assert conv.sub_id == "click_abc_123"
    assert conv.payout == 45.0
    assert conv.status == "sale"

    # Missing sub_id failure
    assert {:error, :missing_sub_id} = PostbackService.process_postback(%{})
  end

  test "TrackerScriptService generates IIFE tracker javascript" do
    script = TrackerScriptService.get_script("app_test_camp", %{host: "cdn.traffic.com"})
    assert script =~ "(function(window, document)"
    assert script =~ "app_test_camp"
    assert script =~ "k_encounter=2"
  end
end
