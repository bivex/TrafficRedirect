defmodule TrafficRedirect.Domain.Action.BaseHelper do
  @moduledoc false
  alias TrafficRedirect.Domain.Macro.Processor
  alias TrafficRedirect.Domain.Model.Payload

  def resolve_target_url(%Payload{} = payload) do
    raw_url =
      cond do
        payload.offer && payload.offer.url -> payload.offer.url
        payload.action_payload && is_binary(payload.action_payload) -> payload.action_payload
        payload.landing && payload.landing.url -> payload.landing.url
        true -> "https://google.com"
      end

    Processor.process(raw_url, payload)
  end
end
