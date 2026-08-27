defmodule TrafficRedirect.Domain.MacroProcessorTest do
  use ExUnit.Case, async: true
  alias TrafficRedirect.Domain.Macro.Processor
  alias TrafficRedirect.Domain.Model.{Campaign, Conversion, Offer, Payload, RawClick, Stream}

  test "returns string unchanged when no macro syntax is present" do
    assert Processor.process("https://example.com/direct", %Payload{}) == "https://example.com/direct"
  end

  test "resolves subid, tid, keyword, source, country, ip from RawClick" do
    click = %RawClick{
      sub_id: "sub_12345",
      token: "token_abcde",
      keyword: "best shoes",
      source: "facebook",
      country: "US",
      real_remote_ip: "1.2.3.4"
    }

    payload = %Payload{raw_click: click}
    template = "https://offer.com/?s={subid}&t={tid}&kw={keyword}&src={source}&c={country}&ip={ip}"
    result = Processor.process(template, payload)

    assert result == "https://offer.com/?s=sub_12345&t=token_abcde&kw=best+shoes&src=facebook&c=US&ip=1.2.3.4"
  end

  test "supports raw mode {macro!} without URL encoding" do
    click = %RawClick{keyword: "best shoes & clothes"}
    payload = %Payload{raw_click: click}

    encoded = Processor.process("https://offer.com/?kw={keyword}", payload)
    raw = Processor.process("https://offer.com/?kw={keyword!}", payload)

    assert encoded == "https://offer.com/?kw=best+shoes+%26+clothes"
    assert raw == "https://offer.com/?kw=best shoes & clothes"
  end

  test "resolves sub_id with index argument {sub_id:2}" do
    click = %RawClick{
      sub_ids: %{"sub_id_1" => "src_1", "sub_id_2" => "camp_2", "sub_id_3" => "creative_3"}
    }
    payload = %Payload{raw_click: click}
    template = "https://offer.com/?sub2={sub_id:2}&sub3={sub_id:3}"
    result = Processor.process(template, payload)

    assert result == "https://offer.com/?sub2=camp_2&sub3=creative_3"
  end

  test "resolves campaign, stream, and offer metadata" do
    campaign = %Campaign{id: "1", alias: "nike_sale", name: "Nike Campaign"}
    stream = %Stream{id: "10", campaign_id: "1", name: "Mobile Stream"}
    offer = %Offer{id: "100", name: "Nike 50% Off", payout: 35.5}

    payload = %Payload{
      campaign: campaign,
      stream: stream,
      offer: offer,
      raw_click: %RawClick{cost: 0.15, cost_currency: "USD"}
    }

    template = "https://network.com/?cmp={campaign_alias}&st={stream_name}&off={offer_name}&payout={offer_value}&cost={cost}&cur={currency}"
    result = Processor.process(template, payload)

    assert result == "https://network.com/?cmp=nike_sale&st=Mobile+Stream&off=Nike+50%25+Off&payout=35.5&cost=0.15&cur=USD"
  end

  test "resolves Conversion macros" do
    conversion = %Conversion{
      sub_id: "sub_999",
      token: "tok_888",
      payout: 50.0,
      currency: "EUR",
      status: "sale",
      original_status: "lead"
    }

    template = "https://tracker.com/postback?sub_id={subid}&tid={tid}&payout={payout}&status={status}&curr={currency}"
    result = Processor.process(template, conversion)

    assert result == "https://tracker.com/postback?sub_id=sub_999&tid=tok_888&payout=50.0&status=sale&curr=EUR"
  end

  test "falls back to request query parameters for unknown macros" do
    payload = %Payload{
      request: %{query_params: %{"custom_tag" => "spring_promo"}},
      raw_click: %RawClick{}
    }

    template = "https://example.com/?tag={custom_tag}"
    result = Processor.process(template, payload)

    assert result == "https://example.com/?tag=spring_promo"
  end
end
