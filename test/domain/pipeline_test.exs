defmodule TrafficRedirect.Domain.PipelineTest do
  use ExUnit.Case, async: false
  alias TrafficRedirect.Domain.Model.{
    Campaign,
    Offer,
    Payload,
    RawClick,
    Stream
  }
  alias TrafficRedirect.Domain.Pipeline.Runner
  alias TrafficRedirect.Infrastructure.Adapters.Storage.{
    MemoryCampaignRepo,
    MemoryDomainRepo,
    MemoryOfferRepo,
    MemorySessionRepo,
    MemoryStreamRepo
  }

  test "Pipeline executes full first encounter and generates 302 redirect with macros" do
    campaign = %Campaign{
      id: "pipeline_camp_1",
      alias: "promo",
      name: "Promo Campaign",
      cost_default: 0.25
    }
    MemoryCampaignRepo.save(campaign)

    offer = %Offer{
      id: "offer_100",
      name: "CPA Offer",
      url: "https://cpa.com/offer?s={subid}&tid={tid}&cost={cost}&cntry={country}",
      payout: 20.0,
      share: 100
    }
    MemoryOfferRepo.save(offer)

    stream = %Stream{
      id: "stream_10",
      campaign_id: "pipeline_camp_1",
      name: "Main Stream",
      type: :regular,
      action_type: "http",
      offers: [offer],
      weight: 100
    }
    MemoryStreamRepo.save(stream)

    context = %{
      campaign_repo: MemoryCampaignRepo,
      stream_repo: MemoryStreamRepo,
      offer_repo: MemoryOfferRepo,
      domain_repo: MemoryDomainRepo,
      session_repo: MemorySessionRepo,
      geo_service: TrafficRedirect.Infrastructure.Adapters.Detectors.GeoService,
      device_detector: TrafficRedirect.Infrastructure.Adapters.Detectors.DeviceDetector,
      bot_detector: TrafficRedirect.Infrastructure.Adapters.Detectors.BotDetector,
      click_queue: TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker
    }

    initial_payload = %Payload{
      request: %{
        query_params: %{"k_router_campaign" => "promo", "keyword" => "shoes"},
        headers: %{"user-agent" => "Mozilla/5.0", "x-real-ip" => "1.1.1.1"},
        host: "traffic.com"
      },
      raw_click: %RawClick{}
    }

    final_payload = Runner.run(initial_payload, context)

    refute final_payload.aborted
    assert final_payload.campaign.id == "pipeline_camp_1"
    assert final_payload.stream.id == "stream_10"
    assert final_payload.offer.id == "offer_100"
    assert final_payload.raw_click.cost == 0.25
    assert final_payload.raw_click.country == "US"
    assert is_binary(final_payload.raw_click.sub_id)
    assert is_binary(final_payload.raw_click.token)

    assert final_payload.response.status == 302
    location = final_payload.response.headers["location"]
    assert location =~ "https://cpa.com/offer?"
    assert location =~ "cntry=US"
    assert location =~ "cost=0.25"
    assert location =~ "s=#{final_payload.raw_click.sub_id}"
    assert location =~ "tid=#{final_payload.raw_click.token}"
  end

  test "Pipeline aborts with 404 when campaign is not found" do
    context = %{
      campaign_repo: MemoryCampaignRepo,
      domain_repo: MemoryDomainRepo
    }

    initial_payload = %Payload{
      request: %{query_params: %{"k_router_campaign" => "completely_unknown_camp"}},
      raw_click: %RawClick{}
    }

    final_payload = Runner.run(initial_payload, context)

    assert final_payload.aborted
    assert final_payload.response.status == 404
  end

  test "StaticServingStage aborts early for static assets" do
    initial_payload = %Payload{
      request: %{path_info: ["images", "banner.png"]},
      raw_click: %RawClick{}
    }

    final_payload = Runner.run(initial_payload, %{})

    assert final_payload.aborted
    assert final_payload.response.status == 200
    assert final_payload.response.headers["x-accel-redirect"] == "/internal-redirect/images/banner.png"
  end

  test "Click API returns JSON output" do
    campaign = %Campaign{id: "api_camp_1", alias: "api_campaign"}
    MemoryCampaignRepo.save(campaign)

    offer = %Offer{id: "api_off_50", url: "https://target.com/go"}
    MemoryOfferRepo.save(offer)

    stream = %Stream{id: "api_str_5", campaign_id: "api_camp_1", offers: [offer]}
    MemoryStreamRepo.save(stream)

    context = %{
      campaign_repo: MemoryCampaignRepo,
      stream_repo: MemoryStreamRepo,
      offer_repo: MemoryOfferRepo
    }

    initial_payload = %Payload{
      request: %{query_params: %{"k_router_campaign" => "api_campaign"}},
      raw_click: %RawClick{},
      is_api_request: true,
      api_version: 1
    }

    final_payload = Runner.run(initial_payload, context)

    assert final_payload.response.status == 200
    assert final_payload.response.headers["content-type"] =~ "application/json"

    data = Jason.decode!(final_payload.response.body)
    assert data["status"] == "success"
    assert data["redirect_url"] == "https://target.com/go"
    assert data["campaign_id"] == "api_camp_1"
    assert data["offer_id"] == "api_off_50"
  end
end
