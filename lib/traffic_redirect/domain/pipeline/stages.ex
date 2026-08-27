defmodule TrafficRedirect.Domain.Pipeline.Stage do
  @moduledoc """
  Stage behaviour for the Click Pipeline (Chain of Responsibility pattern).
  """
  alias TrafficRedirect.Domain.Model.Payload

  @callback execute(payload :: Payload.t(), context :: map()) :: Payload.t()
end

# 1. StaticServingStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.StaticServingStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{request: req} = payload, _ctx) do
    path = req && Map.get(req, :path_info, [])
    if is_list(path) and List.last(path) && String.match?(List.last(path), ~r/\.(css|js|png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf)$/i) do
      file_path = "/" <> Enum.join(path, "/")
      resp = %RedirectResponse{
        status: 200,
        headers: %{"x-accel-redirect" => "/internal-redirect" <> file_path},
        body: "",
        action_type: "static"
      }
      %{payload | response: resp, aborted: true}
    else
      payload
    end
  end
end

# 2. CheckCacheStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.CheckCacheStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{} = payload, _ctx), do: payload
end

# 3. HttpsRedirectStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.HttpsRedirectStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{request: req} = payload, _ctx) do
    scheme = (req && Map.get(req, :scheme)) || "http"
    force_ssl = Application.get_env(:traffic_redirect, :force_ssl, false)

    if force_ssl and scheme == "http" do
      host = Map.get(req, :host, "localhost")
      req_path = Map.get(req, :request_path, "/")
      query = Map.get(req, :query_string, "")
      url = "https://#{host}#{req_path}" <> if(query != "", do: "?#{query}", else: "")
      resp = RedirectResponse.redirect(url, 301)
      %{payload | response: resp, aborted: true}
    else
      payload
    end
  end
end

# 4. CheckPrefetchStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.CheckPrefetchStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{request: req} = payload, _ctx) do
    headers = (req && Map.get(req, :headers, %{})) || %{}
    is_prefetch =
      Map.get(headers, "purpose") == "prefetch" or
      Map.get(headers, "x-purpose") == "preview" or
      Map.get(headers, "sec-purpose") == "prefetch"

    if is_prefetch do
      resp = %RedirectResponse{status: 204, headers: %{}, body: "", action_type: "prefetch_drop"}
      %{payload | response: resp, aborted: true}
    else
      payload
    end
  end
end

# 5. FindCampaignStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.FindCampaignStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.{Payload, RawClick}

  def execute(%Payload{campaign: nil, request: req} = payload, ctx) do
    campaign_repo = Map.get(ctx, :campaign_repo)
    domain_repo = Map.get(ctx, :domain_repo)

    query_params = (req && Map.get(req, :query_params, %{})) || %{}
    alias_param = Map.get(query_params, "k_router_campaign") || Map.get(query_params, "alias")
    host = (req && Map.get(req, :host)) || "localhost"

    campaign =
      cond do
        alias_param && campaign_repo ->
          campaign_repo.get_by_alias(alias_param)

        domain_repo && campaign_repo ->
          case domain_repo.get_by_domain(host) do
            nil -> nil
            dom -> dom.default_campaign_id && campaign_repo.get_by_id(dom.default_campaign_id)
          end

        true ->
          nil
      end

    if campaign do
      raw_click =
        payload.raw_click
        |> Map.put(:campaign_id, campaign.id)
        |> Map.put(:campaign_alias, campaign.alias)
        |> RawClick.put_if_nil(:traffic_source_id, campaign.traffic_source_id)

      %{payload | campaign: campaign, raw_click: raw_click}
    else
      payload
    end
  end

  def execute(payload, _ctx), do: payload
end

# 6. NoCampaignCatcherStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.NoCampaignCatcherStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{campaign: nil} = payload, _ctx) do
    resp = %RedirectResponse{
      status: 404,
      headers: %{"content-type" => "text/html; charset=utf-8"},
      body: "<h1>404 Campaign Not Found</h1>",
      action_type: "no_campaign_404"
    }
    %{payload | response: resp, aborted: true}
  end

  def execute(payload, _ctx), do: payload
end

# 7. CheckBypassCacheStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.CheckBypassCacheStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{request: req} = payload, _ctx) do
    query = (req && Map.get(req, :query_params, %{})) || %{}
    if Map.get(query, "bypass_cache") in ["1", "true"] do
      %{payload | metadata: Map.put(payload.metadata, :bypass_cache, true)}
    else
      payload
    end
  end
end

# 8. FillClickInformationStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.FillClickInformationStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.{Payload, RawClick}

  def execute(%Payload{request: req, raw_click: click} = payload, ctx) do
    query = (req && Map.get(req, :query_params, %{})) || %{}
    headers = (req && Map.get(req, :headers, %{})) || %{}

    ip =
      Map.get(headers, "cf-connecting-ip") ||
      Map.get(headers, "x-real-ip") ||
      (Map.get(headers, "x-forwarded-for") && String.split(headers["x-forwarded-for"], ",") |> List.first() |> String.trim()) ||
      (req && Map.get(req, :remote_ip)) ||
      "127.0.0.1"

    ua = Map.get(headers, "user-agent", "")
    lang = Map.get(headers, "accept-language", "")
    ref = Map.get(headers, "referer", "")
    se_ref = Map.get(query, "se_referrer", "")

    source = Map.get(query, "source") || (ref != "" && URI.parse(ref).host) || ""
    keyword = Map.get(query, "keyword") || Map.get(query, "default_keyword") || ""

    sub_ids = extract_sub_ids(query)
    extra_params = extract_extra_params(query)

    cost = parse_float(Map.get(query, "cost", "0.0"))
    currency = Map.get(query, "currency", "USD")

    geo_service = Map.get(ctx, :geo_service)
    device_detector = Map.get(ctx, :device_detector)
    bot_detector = Map.get(ctx, :bot_detector)

    geo_info = if geo_service, do: geo_service.lookup(ip), else: %{country: "US", region: "CA", city: "Los Angeles"}
    device_info = if device_detector, do: device_detector.detect(ua), else: %{device_type: :desktop, os: "macOS", browser: "Chrome"}
    bot_info = if bot_detector, do: bot_detector.detect(ua, ip, headers), else: %{is_bot: false, is_proxy: false}

    updated_click =
      click
      |> RawClick.put_if_nil(:ip, ip)
      |> RawClick.put_if_nil(:real_remote_ip, ip)
      |> RawClick.put_if_nil(:user_agent, ua)
      |> RawClick.put_if_nil(:language, lang)
      |> RawClick.put_if_nil(:referrer, ref)
      |> RawClick.put_if_nil(:se_referrer, se_ref)
      |> RawClick.put_if_nil(:source, source)
      |> RawClick.put_if_nil(:keyword, keyword)
      |> RawClick.put_if_nil(:cost, cost)
      |> RawClick.put_if_nil(:cost_currency, currency)
      |> RawClick.put_if_nil(:country, geo_info[:country])
      |> RawClick.put_if_nil(:region, geo_info[:region])
      |> RawClick.put_if_nil(:city, geo_info[:city])
      |> RawClick.put_if_nil(:isp, geo_info[:isp])
      |> RawClick.put_if_nil(:operator, geo_info[:operator])
      |> RawClick.put_if_nil(:connection_type, geo_info[:connection_type])
      |> RawClick.put_if_nil(:device_type, device_info[:device_type])
      |> RawClick.put_if_nil(:device_model, device_info[:device_model])
      |> RawClick.put_if_nil(:os, device_info[:os])
      |> RawClick.put_if_nil(:os_version, device_info[:os_version])
      |> RawClick.put_if_nil(:browser, device_info[:browser])
      |> RawClick.put_if_nil(:browser_version, device_info[:browser_version])
      |> RawClick.put_if_nil(:is_bot, bot_info[:is_bot] || false)
      |> RawClick.put_if_nil(:is_proxy, bot_info[:is_proxy] || false)
      |> RawClick.put_if_nil(:x_requested_with, Map.get(headers, "x-requested-with"))
      |> Map.put(:sub_ids, Map.merge(click.sub_ids || %{}, sub_ids))
      |> Map.put(:extra_params, Map.merge(click.extra_params || %{}, extra_params))
      |> Map.put(:custom_params, query)

    %{payload | raw_click: updated_click}
  end

  defp extract_sub_ids(query) do
    Enum.reduce(query, %{}, fn {k, v}, acc ->
      if String.match?(k, ~r/^(sub_id|subid)_?\d+$/i) do
        Map.put(acc, String.downcase(k), v)
      else
        acc
      end
    end)
  end

  defp extract_extra_params(query) do
    Enum.reduce(query, %{}, fn {k, v}, acc ->
      if String.match?(k, ~r/^extra_param_\d+$/i) do
        Map.put(acc, String.downcase(k), v)
      else
        acc
      end
    end)
  end

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end
  defp parse_float(val) when is_number(val), do: val * 1.0
  defp parse_float(_), do: 0.0
end

# 9. ParamsPreprocessStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.ParamsPreprocessStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{} = payload, _ctx), do: payload
end

# 10. GenerateVisitorCodeStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.GenerateVisitorCodeStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{raw_click: click} = payload, _ctx) do
    if is_nil(click.visitor_code) do
      seed = "#{click.ip}:#{click.user_agent}"
      code = :crypto.hash(:md5, seed) |> Base.encode16(case: :lower)
      %{payload | raw_click: %{click | visitor_code: code}}
    else
      payload
    end
  end
end

# 11. GenerateSubIdStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.GenerateSubIdStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{raw_click: click} = payload, _ctx) do
    if is_nil(click.sub_id) do
      timestamp = System.os_time(:millisecond)
      random = :rand.uniform(999_999)
      sub_id = "#{timestamp}#{random}"
      %{payload | raw_click: %{click | sub_id: sub_id}}
    else
      payload
    end
  end
end

# 12. LoadOrCreateSessionStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.LoadOrCreateSessionStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.{Payload, Session}

  def execute(%Payload{session: nil, raw_click: click} = payload, ctx) do
    session_repo = Map.get(ctx, :session_repo)
    visitor_code = click.visitor_code

    session =
      if session_repo && visitor_code do
        session_repo.get_by_visitor_code(visitor_code) ||
          %Session{
            id: visitor_code,
            visitor_code: visitor_code,
            campaign_id: click.campaign_id,
            sub_id: click.sub_id,
            first_hit_at: DateTime.utc_now(),
            last_hit_at: DateTime.utc_now()
          }
      else
        %Session{
          id: visitor_code || "anon",
          visitor_code: visitor_code || "anon",
          campaign_id: click.campaign_id,
          sub_id: click.sub_id,
          first_hit_at: DateTime.utc_now(),
          last_hit_at: DateTime.utc_now()
        }
      end

    %{payload | session: session}
  end

  def execute(payload, _ctx), do: payload
end

# 13. CheckParamAliasesStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.CheckParamAliasesStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{} = payload, _ctx), do: payload
end

# 14. UpdateCampaignUniquenessStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.UpdateCampaignUniquenessStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{session: session, raw_click: click} = payload, _ctx) do
    is_unique = is_nil(session) or (session.hit_count || 1) <= 1
    %{payload | raw_click: %{click | is_unique_campaign: is_unique}}
  end
end

# 15. ChooseStreamStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.ChooseStreamStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload
  alias TrafficRedirect.Domain.Strategy.Stream.{BoundStrategy, PositionStrategy, WeightStrategy}

  def execute(%Payload{stream: nil, campaign: campaign, raw_click: click} = payload, ctx) do
    stream_repo = Map.get(ctx, :stream_repo)
    streams = if stream_repo && campaign, do: stream_repo.get_active_by_campaign_id(campaign.id), else: []

    forced_streams = Enum.filter(streams, &(&1.type == :forced))
    regular_streams = Enum.filter(streams, &(&1.type == :regular))
    default_streams = Enum.filter(streams, &(&1.type == :default))

    chosen_stream =
      PositionStrategy.select(forced_streams, click) ||
        (if campaign && campaign.bind_visitors, do: BoundStrategy.select(regular_streams, payload)) ||
        (if campaign && campaign.type == :position, do: PositionStrategy.select(regular_streams, click)) ||
        WeightStrategy.select(regular_streams, click, %{}) ||
        List.first(default_streams) ||
        List.first(streams)

    if chosen_stream do
      raw_click = %{click | stream_id: chosen_stream.id}
      %{payload | stream: chosen_stream, raw_click: raw_click}
    else
      payload
    end
  end

  def execute(payload, _ctx), do: payload
end

# 16. ApplyStreamActionStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.ApplyStreamActionStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{stream: stream} = payload, _ctx) when not is_nil(stream) do
    %{
      payload
      | action_type: stream.action_type || "http",
        action_payload: stream.action_payload,
        action_options: stream.action_options || %{}
    }
  end

  def execute(payload, _ctx), do: payload
end

# 17. UpdateStreamUniquenessStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.UpdateStreamUniquenessStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{raw_click: click} = payload, _ctx) do
    %{payload | raw_click: %{click | is_unique_stream: click.is_unique_campaign}}
  end
end

# 18. ChooseLandingStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.ChooseLandingStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload
  alias TrafficRedirect.Domain.Strategy.Landing.LandingPageRotator

  def execute(%Payload{landing: nil, stream: stream} = payload, ctx) when not is_nil(stream) do
    landing_repo = Map.get(ctx, :landing_repo)

    landings =
      cond do
        stream.landings && stream.landings != [] -> stream.landings
        landing_repo -> landing_repo.get_by_stream_id(stream.id)
        true -> []
      end

    chosen_landing = LandingPageRotator.select(landings, payload)

    if chosen_landing do
      raw_click = %{payload.raw_click | landing_id: chosen_landing.id}
      %{
        payload
        | landing: chosen_landing,
          raw_click: raw_click,
          action_type: chosen_landing.action_type || payload.action_type,
          action_payload: chosen_landing.action_payload || payload.action_payload,
          action_options: chosen_landing.action_options || payload.action_options
      }
    else
      payload
    end
  end

  def execute(payload, _ctx), do: payload
end

# 19. ChooseOfferStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.ChooseOfferStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload
  alias TrafficRedirect.Domain.Strategy.Offer.OfferPageRotator

  def execute(%Payload{offer: nil, stream: stream} = payload, ctx) when not is_nil(stream) do
    offer_repo = Map.get(ctx, :offer_repo)

    offers =
      cond do
        stream.offers && stream.offers != [] -> stream.offers
        offer_repo -> offer_repo.get_by_stream_id(stream.id)
        true -> []
      end

    chosen_offer = OfferPageRotator.select(offers, payload)

    if chosen_offer do
      raw_click =
        payload.raw_click
        |> Map.put(:offer_id, chosen_offer.id)
        |> Map.put(:payout, chosen_offer.payout || 0.0)
        |> Map.put(:payout_currency, chosen_offer.payout_currency || "USD")

      %{
        payload
        | offer: chosen_offer,
          raw_click: raw_click,
          action_type: chosen_offer.action_type || payload.action_type,
          action_payload: chosen_offer.action_payload || chosen_offer.url || payload.action_payload,
          action_options: chosen_offer.action_options || payload.action_options
      }
    else
      payload
    end
  end

  def execute(payload, _ctx), do: payload
end

# 20. GenerateTokenStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.GenerateTokenStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{raw_click: click} = payload, _ctx) do
    if is_nil(click.token) do
      token = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
      %{payload | raw_click: %{click | token: token}}
    else
      payload
    end
  end
end

# 21. FindAffiliateNetworkStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.FindAffiliateNetworkStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{offer: offer, raw_click: click} = payload, ctx) when not is_nil(offer) do
    network_repo = Map.get(ctx, :affiliate_network_repo)
    network = if network_repo && offer.affiliate_network_id, do: network_repo.get_by_id(offer.affiliate_network_id), else: nil

    if network do
      raw_click = %{click | affiliate_network_id: network.id}
      %{payload | affiliate_network: network, raw_click: raw_click}
    else
      payload
    end
  end

  def execute(payload, _ctx), do: payload
end

# 22. UpdateHitLimitStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.UpdateHitLimitStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{} = payload, _ctx), do: payload
end

# 23. UpdateCostsStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.UpdateCostsStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{campaign: campaign, raw_click: click} = payload, _ctx) do
    cost =
      if (is_nil(click.cost) or click.cost == 0.0) && campaign && campaign.cost_default > 0.0 do
        campaign.cost_default
      else
        click.cost || 0.0
      end

    %{payload | raw_click: %{click | cost: cost}}
  end
end

# 24. UpdatePayoutStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.UpdatePayoutStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{offer: offer, raw_click: click} = payload, _ctx) do
    payout = if offer && offer.payout, do: offer.payout, else: click.payout || 0.0
    profit = (click.revenue || 0.0) - (click.cost || 0.0)
    %{payload | raw_click: %{click | payout: payout, profit: profit}}
  end
end

# 25. PrepareRawClickToStoreStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.PrepareRawClickToStoreStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{raw_click: click} = payload, _ctx) do
    updated_click = %{click | created_at: DateTime.utc_now()}
    %{payload | raw_click: updated_click}
  end
end

# 26. SaveSessionStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.SaveSessionStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{session: session, raw_click: click} = payload, ctx) when not is_nil(session) do
    session_repo = Map.get(ctx, :session_repo)

    updated_session = %{
      session
      | stream_id: click.stream_id || session.stream_id,
        landing_id: click.landing_id || session.landing_id,
        offer_id: click.offer_id || session.offer_id,
        sub_id: click.sub_id || session.sub_id,
        token: click.token || session.token,
        hit_count: (session.hit_count || 0) + 1,
        last_hit_at: DateTime.utc_now()
    }

    if session_repo do
      session_repo.save(updated_session)
    end

    %{payload | session: updated_session}
  end

  def execute(payload, _ctx), do: payload
end

# 27. CheckSendingToAnotherCampaignStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.CheckSendingToAnotherCampaignStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}
  alias TrafficRedirect.Domain.Pipeline.Runner

  @max_chain_depth 5

  def execute(%Payload{action_type: action_type, chain_count: count} = payload, ctx)
      when action_type in ["campaign", "group"] do
    if count >= @max_chain_depth do
      resp = RedirectResponse.redirect("https://google.com", 302)
      %{payload | response: resp, aborted: true}
    else
      target_campaign_id = payload.action_payload
      campaign_repo = Map.get(ctx, :campaign_repo)
      target_campaign = campaign_repo && campaign_repo.get_by_id(target_campaign_id)

      if target_campaign do
        cleaned_payload = %Payload{
          request: payload.request,
          campaign: target_campaign,
          raw_click: %{
            payload.raw_click
            | parent_campaign_id: payload.campaign && payload.campaign.id,
              parent_sub_id: payload.raw_click.sub_id,
              campaign_id: target_campaign.id,
              campaign_alias: target_campaign.alias,
              stream_id: nil,
              landing_id: nil,
              offer_id: nil
          },
          chain_count: count + 1,
          context: payload.context,
          is_api_request: payload.is_api_request,
          api_version: payload.api_version
        }

        Runner.run(cleaned_payload, ctx)
      else
        payload
      end
    end
  end

  def execute(payload, _ctx), do: payload
end

# 28. UpdateTokenStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.UpdateTokenStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{} = payload, _ctx), do: payload
end

# 29. ExecuteActionStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.ExecuteActionStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Action.Registry, as: ActionRegistry
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  def execute(%Payload{response: nil, is_api_request: true} = payload, _ctx) do
    action_module = ActionRegistry.get(payload.action_type)
    domain_resp = action_module.execute(payload)

    api_result = %{
      "status" => "success",
      "sub_id" => payload.raw_click.sub_id,
      "token" => payload.raw_click.token,
      "action_type" => payload.action_type,
      "redirect_url" => domain_resp.target_url,
      "landing_id" => payload.raw_click.landing_id,
      "offer_id" => payload.raw_click.offer_id,
      "campaign_id" => payload.raw_click.campaign_id
    }

    resp = RedirectResponse.json(api_result, 200)
    %{payload | response: resp}
  end

  def execute(%Payload{response: nil} = payload, _ctx) do
    action_module = ActionRegistry.get(payload.action_type)
    resp = action_module.execute(payload)
    %{payload | response: resp}
  end

  def execute(payload, _ctx), do: payload
end

# 30. SaveRawClicksStage
defmodule TrafficRedirect.Domain.Pipeline.Stages.SaveRawClicksStage do
  @behaviour TrafficRedirect.Domain.Pipeline.Stage
  alias TrafficRedirect.Domain.Model.Payload

  def execute(%Payload{raw_click: click, stream: stream} = payload, ctx) do
    collect_clicks = is_nil(stream) or stream.collect_clicks
    disable_stats = Application.get_env(:traffic_redirect, :disable_stats, false)

    if collect_clicks and not disable_stats do
      click_queue = Map.get(ctx, :click_queue)
      if click_queue do
        click_queue.enqueue(click)
      end
    end

    payload
  end
end

defmodule TrafficRedirect.Domain.Pipeline.Runner do
  @moduledoc """
  Pipeline Runner executing the ordered 30 stages with abort support.
  """
  alias TrafficRedirect.Domain.Model.Payload
  alias TrafficRedirect.Domain.Pipeline.Stages

  @stages [
    Stages.StaticServingStage,
    Stages.CheckCacheStage,
    Stages.HttpsRedirectStage,
    Stages.CheckPrefetchStage,
    Stages.FindCampaignStage,
    Stages.NoCampaignCatcherStage,
    Stages.CheckBypassCacheStage,
    Stages.FillClickInformationStage,
    Stages.ParamsPreprocessStage,
    Stages.GenerateVisitorCodeStage,
    Stages.GenerateSubIdStage,
    Stages.LoadOrCreateSessionStage,
    Stages.CheckParamAliasesStage,
    Stages.UpdateCampaignUniquenessStage,
    Stages.ChooseStreamStage,
    Stages.ApplyStreamActionStage,
    Stages.UpdateStreamUniquenessStage,
    Stages.ChooseLandingStage,
    Stages.ChooseOfferStage,
    Stages.GenerateTokenStage,
    Stages.FindAffiliateNetworkStage,
    Stages.UpdateHitLimitStage,
    Stages.UpdateCostsStage,
    Stages.UpdatePayoutStage,
    Stages.PrepareRawClickToStoreStage,
    Stages.SaveSessionStage,
    Stages.CheckSendingToAnotherCampaignStage,
    Stages.UpdateTokenStage,
    Stages.ExecuteActionStage,
    Stages.SaveRawClicksStage
  ]

  @doc """
  Runs the payload through the stages sequentially until completion or abort.
  """
  def run(%Payload{} = payload, context \\ %{}) do
    Enum.reduce_while(@stages, payload, fn stage, current_payload ->
      if current_payload.aborted do
        {:halt, current_payload}
      else
        next_payload = stage.execute(current_payload, context)
        if next_payload.aborted do
          {:halt, next_payload}
        else
          {:cont, next_payload}
        end
      end
    end)
  end
end
