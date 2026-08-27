defmodule TrafficRedirect.Domain.ActionsTest do
  use ExUnit.Case, async: true
  alias TrafficRedirect.Domain.Action.Actions.{
    BlankReferrer,
    DoubleMeta,
    FormSubmit,
    HttpRedirect,
    Iframe,
    Js,
    Meta,
    ShowHtml,
    ShowText,
    SubId
  }
  alias TrafficRedirect.Domain.Model.{Offer, Payload, RawClick}

  test "HttpRedirect returns 302 Location in default context" do
    offer = %Offer{id: "1", url: "https://example.com/target"}
    payload = %Payload{offer: offer, context: :default}

    resp = HttpRedirect.execute(payload)
    assert resp.status == 302
    assert resp.headers["location"] == "https://example.com/target"
  end

  test "HttpRedirect returns JS in script context" do
    offer = %Offer{id: "1", url: "https://example.com/target"}
    payload = %Payload{offer: offer, context: :script}

    resp = HttpRedirect.execute(payload)
    assert resp.status == 200
    assert resp.headers["content-type"] =~ "application/javascript"
    assert resp.body =~ "window.location.href = 'https://example.com/target';"
  end

  test "Js action returns script redirect" do
    offer = %Offer{id: "1", url: "https://example.com/target"}
    payload = %Payload{offer: offer}

    resp = Js.execute(payload)
    assert resp.status == 200
    assert resp.body =~ "window.top.location.href"
    assert resp.body =~ "https://example.com/target"
  end

  test "Meta action returns meta-refresh HTML" do
    offer = %Offer{id: "1", url: "https://example.com/target"}
    payload = %Payload{offer: offer, action_options: %{delay: 2}}

    resp = Meta.execute(payload)
    assert resp.status == 200
    assert resp.body =~ ~s(<meta http-equiv="refresh" content="2; URL=https://example.com/target">)
  end

  test "DoubleMeta action generates gateway redirect with signed JWT" do
    offer = %Offer{id: "1", url: "https://example.com/target"}
    click = %RawClick{user_agent: "Mozilla/5.0 Safari"}
    payload = %Payload{offer: offer, raw_click: click}

    resp = DoubleMeta.execute(payload)
    assert resp.status == 302
    assert String.starts_with?(resp.headers["location"], "/gateway.php?frm=dm&token=")
  end

  test "BlankReferrer action includes no-referrer meta tag" do
    offer = %Offer{id: "1", url: "https://example.com/target"}
    payload = %Payload{offer: offer}

    resp = BlankReferrer.execute(payload)
    assert resp.status == 200
    assert resp.body =~ ~s(<meta name="referrer" content="no-referrer">)
  end

  test "Iframe action returns iframe HTML in default context and 302 in frame context" do
    offer = %Offer{id: "1", url: "https://example.com/target"}

    resp_default = Iframe.execute(%Payload{offer: offer, context: :default})
    assert resp_default.status == 200
    assert resp_default.body =~ ~s(<iframe src="https://example.com/target"></iframe>)

    resp_frame = Iframe.execute(%Payload{offer: offer, context: :frame})
    assert resp_frame.status == 302
    assert resp_frame.headers["location"] == "https://example.com/target"
  end

  test "FormSubmit action auto-submits POST form with hidden inputs" do
    offer = %Offer{id: "1", url: "https://partner.com/lead"}
    payload = %Payload{
      offer: offer,
      request: %{query_params: %{"first_name" => "John", "phone" => "+123456789"}}
    }

    resp = FormSubmit.execute(payload)
    assert resp.status == 200
    assert resp.body =~ ~s(<form id="redirectForm" method="POST" action="https://partner.com/lead">)
    assert resp.body =~ ~s(<input type="hidden" name="first_name" value="John">)
    assert resp.body =~ ~s(<input type="hidden" name="phone" value="+123456789">)
  end

  test "ShowText and ShowHtml actions" do
    payload_text = %Payload{action_payload: "Hello World"}
    resp_text = ShowText.execute(payload_text)
    assert resp_text.status == 200
    assert resp_text.headers["content-type"] =~ "text/plain"
    assert resp_text.body == "Hello World"

    payload_html = %Payload{action_payload: "<h1>Hello World</h1>"}
    resp_html = ShowHtml.execute(payload_html)
    assert resp_html.status == 200
    assert resp_html.headers["content-type"] =~ "text/html"
    assert resp_html.body == "<h1>Hello World</h1>"
  end

  test "SubId action supports plain response and JSONP callback" do
    click = %RawClick{sub_id: "click_12345"}

    # Plain sub_id
    resp_plain = SubId.execute(%Payload{raw_click: click})
    assert resp_plain.status == 200
    assert resp_plain.body == "click_12345"

    # JSONP return
    resp_jsonp = SubId.execute(%Payload{
      raw_click: click,
      request: %{query_params: %{"return" => "jsonp", "callback" => "MyTracker.handle"}}
    })
    assert resp_jsonp.status == 200
    assert resp_jsonp.body == "MyTracker.handle(\"click_12345\");"
  end
end
