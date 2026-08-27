defmodule TrafficRedirect.Application.Services.ClickService do
  @moduledoc """
  Application Service for executing visitor traffic click pipeline.
  Glues Driving Ports with the Domain Pipeline Runner and Outbound Repositories.
  """
  alias TrafficRedirect.Domain.Model.{Payload, RawClick, RedirectResponse}
  alias TrafficRedirect.Domain.Pipeline.Runner

  @behaviour TrafficRedirect.Application.Ports.Inbound.ProcessClickPort

  def process_click(request) when is_map(request) do
    context = build_context()
    frm = Map.get(request[:query_params] || %{}, "frm", "default")
    
    pipeline_context =
      case frm do
        "frame" -> :frame
        "script" -> :script
        _ -> :default
      end

    initial_payload = %Payload{
      request: request,
      raw_click: %RawClick{},
      context: pipeline_context,
      is_first_encounter: true,
      is_api_request: false
    }

    final_payload = Runner.run(initial_payload, context)

    response = final_payload.response || RedirectResponse.redirect("https://google.com", 302)
    {:ok, response}
  end

  defp build_context do
    %{
      campaign_repo: Application.get_env(:traffic_redirect, :campaign_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryCampaignRepo),
      stream_repo: Application.get_env(:traffic_redirect, :stream_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStreamRepo),
      landing_repo: Application.get_env(:traffic_redirect, :landing_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryLandingRepo),
      offer_repo: Application.get_env(:traffic_redirect, :offer_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryOfferRepo),
      domain_repo: Application.get_env(:traffic_redirect, :domain_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryDomainRepo),
      session_repo: Application.get_env(:traffic_redirect, :session_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemorySessionRepo),
      click_queue: Application.get_env(:traffic_redirect, :click_queue, TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker),
      geo_service: Application.get_env(:traffic_redirect, :geo_service, TrafficRedirect.Infrastructure.Adapters.Detectors.GeoService),
      device_detector: Application.get_env(:traffic_redirect, :device_detector, TrafficRedirect.Infrastructure.Adapters.Detectors.DeviceDetector),
      bot_detector: Application.get_env(:traffic_redirect, :bot_detector, TrafficRedirect.Infrastructure.Adapters.Detectors.BotDetector)
    }
  end
end

defmodule TrafficRedirect.Application.Services.ClickApiService do
  @moduledoc """
  Application Service for executing Click API requests (v1-v4).
  """
  alias TrafficRedirect.Domain.Model.{Payload, RawClick, RedirectResponse}
  alias TrafficRedirect.Domain.Pipeline.Runner

  @behaviour TrafficRedirect.Application.Ports.Inbound.ProcessClickApiPort

  def process_click_api(version, request) when is_integer(version) and is_map(request) do
    context = %{
      campaign_repo: Application.get_env(:traffic_redirect, :campaign_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryCampaignRepo),
      stream_repo: Application.get_env(:traffic_redirect, :stream_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStreamRepo),
      landing_repo: Application.get_env(:traffic_redirect, :landing_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryLandingRepo),
      offer_repo: Application.get_env(:traffic_redirect, :offer_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryOfferRepo),
      domain_repo: Application.get_env(:traffic_redirect, :domain_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryDomainRepo),
      session_repo: Application.get_env(:traffic_redirect, :session_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemorySessionRepo),
      click_queue: Application.get_env(:traffic_redirect, :click_queue, TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker),
      geo_service: Application.get_env(:traffic_redirect, :geo_service, TrafficRedirect.Infrastructure.Adapters.Detectors.GeoService),
      device_detector: Application.get_env(:traffic_redirect, :device_detector, TrafficRedirect.Infrastructure.Adapters.Detectors.DeviceDetector),
      bot_detector: Application.get_env(:traffic_redirect, :bot_detector, TrafficRedirect.Infrastructure.Adapters.Detectors.BotDetector)
    }

    initial_payload = %Payload{
      request: request,
      raw_click: %RawClick{},
      is_first_encounter: true,
      is_api_request: true,
      api_version: version
    }

    final_payload = Runner.run(initial_payload, context)
    response = final_payload.response || RedirectResponse.json(%{"error" => "No response generated"}, 500)
    {:ok, response}
  end
end

defmodule TrafficRedirect.Application.Services.PostbackService do
  @moduledoc """
  Application Service for receiving and recording conversions, with asynchronous postback dispatch.
  """
  alias TrafficRedirect.Domain.Model.Conversion

  @behaviour TrafficRedirect.Application.Ports.Inbound.ProcessPostbackPort

  def process_postback(params) when is_map(params) do
    sub_id = Map.get(params, "sub_id") || Map.get(params, "subid") || Map.get(params, "key")
    payout = parse_float(Map.get(params, "payout") || Map.get(params, "revenue") || "0.0")
    currency = Map.get(params, "currency", "USD")
    status = Map.get(params, "status", "lead")
    tx_id = Map.get(params, "tx_id") || Map.get(params, "tid")

    offer_id = Map.get(params, "offer_id") || Map.get(params, "offer")

    if is_nil(sub_id) or sub_id == "" do
      {:error, :missing_sub_id}
    else
      conversion = %Conversion{
        id: "conv_#{sub_id}_#{System.os_time(:millisecond)}",
        sub_id: sub_id,
        token: Map.get(params, "token"),
        offer_id: offer_id,
        status: status,
        original_status: status,
        payout: payout,
        revenue: payout,
        currency: currency,
        tx_id: tx_id,
        created_at: DateTime.utc_now()
      }

      # Dispatch postback to outgoing queue
      postback_queue = Application.get_env(:traffic_redirect, :postback_queue, TrafficRedirect.Infrastructure.Adapters.Queue.PostbackSenderWorker)
      if postback_queue do
        postback_queue.enqueue(conversion)
      end

      # Increment offer conversions
      offer_repo = Application.get_env(:traffic_redirect, :offer_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryOfferRepo)
      if offer_repo && conversion.offer_id do
        offer_repo.increment_conversions(conversion.offer_id)
      end

      {:ok, conversion}
    end
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

defmodule TrafficRedirect.Application.Services.TrackerScriptService do
  @moduledoc """
  Application Service for serving JS Tracker script.
  """
  alias TrafficRedirect.Domain.Tracker.CodeGenerator

  @behaviour TrafficRedirect.Application.Ports.Inbound.GetTrackerScriptPort

  def get_script(alias_name, options \\ %{}) do
    CodeGenerator.get_code(alias_name, options)
  end
end
