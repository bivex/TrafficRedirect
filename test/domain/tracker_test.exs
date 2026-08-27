defmodule TrafficRedirect.Domain.TrackerTest do
  use ExUnit.Case, async: true
  alias TrafficRedirect.Domain.Tracker.CodeGenerator

  test "generates full featured JS tracker script for campaign alias" do
    code = CodeGenerator.get_code("crypto_offer_lp", %{host: "tracker.mybrand.com"})

    assert code =~ "CONFIG"
    assert code =~ "alias: 'crypto_offer_lp'"
    assert code =~ "//tracker.mybrand.com/crypto_offer_lp"
    assert code =~ "window.TrafficTracker"
    assert code =~ "window.KClient"
    assert code =~ "getSubId"
    assert code =~ "getToken"
    assert code =~ "getOfferUrl"
    assert code =~ "goToOffer"
    assert code =~ "postback"
    assert code =~ "track"
    assert code =~ "setupDomHooks"
    assert code =~ "initEngagementTracking"
  end

  test "generates valid data-URI for inline embedding" do
    data_uri = CodeGenerator.get_data_uri("my_camp")

    assert String.starts_with?(data_uri, "data:application/javascript;base64,")
  end
end
