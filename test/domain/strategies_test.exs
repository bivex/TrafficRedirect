defmodule TrafficRedirect.Domain.StrategiesTest do
  use ExUnit.Case, async: true
  alias TrafficRedirect.Domain.Model.{
    Landing,
    Offer,
    Payload,
    RawClick,
    Session,
    Stream,
    StreamFilter
  }
  alias TrafficRedirect.Domain.Strategy.Landing.LandingPageRotator
  alias TrafficRedirect.Domain.Strategy.Offer.OfferPageRotator
  alias TrafficRedirect.Domain.Strategy.Stream.{BoundStrategy, PositionStrategy, WeightStrategy}

  test "PositionStrategy picks first passing stream in position order" do
    click = %RawClick{country: "DE"}

    s1 = %Stream{id: "1", campaign_id: "1", position: 1, filters: [%StreamFilter{name: "country", payload: "US"}]} # Fails
    s2 = %Stream{id: "2", campaign_id: "1", position: 2, filters: [%StreamFilter{name: "country", payload: "DE"}]} # Passes
    s3 = %Stream{id: "3", campaign_id: "1", position: 3, filters: []} # Passes

    selected = PositionStrategy.select([s3, s1, s2], click)
    assert selected.id == "2"
  end

  test "BoundStrategy respects session stream binding" do
    session = %Session{id: "sess_1", visitor_code: "vc_1", stream_id: "2"}
    payload = %Payload{session: session, raw_click: %RawClick{}}

    s1 = %Stream{id: "1", campaign_id: "1"}
    s2 = %Stream{id: "2", campaign_id: "1"}

    selected = BoundStrategy.select([s1, s2], payload)
    assert selected.id == "2"
  end

  test "WeightStrategy distributes according to weights" do
    s1 = %Stream{id: "1", campaign_id: "1", weight: 90}
    s2 = %Stream{id: "2", campaign_id: "1", weight: 10}
    click = %RawClick{}

    results =
      Enum.reduce(1..1000, %{"1" => 0, "2" => 0}, fn _i, acc ->
        picked = WeightStrategy.select([s1, s2], click, %{})
        Map.update!(acc, to_string(picked.id), &(&1 + 1))
      end)

    # 90% vs 10% with generous statistical margin
    assert results["1"] > 700
    assert results["2"] > 30
  end

  test "LandingPageRotator picks bound landing or weighted landing" do
    l1 = %Landing{id: "1", name: "LP 1", share: 50}
    l2 = %Landing{id: "2", name: "LP 2", share: 50}

    # With visitor binding in session
    session = %Session{id: "s1", visitor_code: "vc1", landing_id: "2"}
    payload = %Payload{session: session}
    assert LandingPageRotator.select([l1, l2], payload).id == "2"

    # Without session binding
    payload_anon = %Payload{session: nil}
    chosen = LandingPageRotator.select([l1, l2], payload_anon)
    assert chosen.id in ["1", "2"]
  end

  test "OfferPageRotator respects explicit ?offer_id= query param" do
    o1 = %Offer{id: "10", name: "Offer 10", share: 100}
    o2 = %Offer{id: "20", name: "Offer 20", share: 100}

    payload = %Payload{
      request: %{query_params: %{"offer_id" => "20"}},
      raw_click: %RawClick{}
    }

    selected = OfferPageRotator.select([o1, o2], payload)
    assert selected.id == "20"
  end

  test "OfferPageRotator skips offers exceeding daily conversion cap" do
    o1 = %Offer{id: "10", daily_cap: 5, conversion_count: 5, share: 100} # Cap reached!
    o2 = %Offer{id: "20", daily_cap: 10, conversion_count: 2, share: 100} # Has capacity

    payload = %Payload{raw_click: %RawClick{}}
    selected = OfferPageRotator.select([o1, o2], payload)
    assert selected.id == "20"
  end
end
