defmodule TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStorage do
  @moduledoc """
  High-performance in-memory ETS storage adapter with zero-allocation concurrent reads.
  """
  use GenServer

  @tables [:campaigns, :campaign_aliases, :streams, :landings, :offers, :domains, :sessions, :clicks]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    Enum.each(@tables, fn table ->
      if :ets.whereis(table) == :undefined do
        :ets.new(table, [:named_table, :public, :set, read_concurrency: true, write_concurrency: true])
      end
    end)

    # Seed sample test campaign for immediate out-of-the-box readiness
    seed_defaults()

    {:ok, %{}}
  end

  defp seed_defaults do
    campaign = %TrafficRedirect.Domain.Model.Campaign{
      id: "1",
      alias: "test_campaign",
      name: "Test Campaign",
      type: :position,
      scheme: :landings_offers
    }

    offer = %TrafficRedirect.Domain.Model.Offer{
      id: "101",
      name: "Sample Offer",
      url: "https://example.com/offer?subid={subid}&tid={tid}",
      action_type: "http",
      payout: 25.0,
      share: 100
    }

    stream = %TrafficRedirect.Domain.Model.Stream{
      id: "10",
      campaign_id: "1",
      name: "Default Stream",
      type: :regular,
      action_type: "http",
      action_payload: "https://example.com/stream?subid={subid}",
      offers: [offer],
      weight: 100
    }

    :ets.insert(:campaigns, {"1", campaign})
    :ets.insert(:campaign_aliases, {"test_campaign", campaign})
    :ets.insert(:streams, {"10", stream})
    :ets.insert(:offers, {"101", offer})
  end
end

defmodule TrafficRedirect.Infrastructure.Adapters.Storage.MemoryCampaignRepo do
  @moduledoc "ETS Implementation of CampaignRepositoryPort"
  @behaviour TrafficRedirect.Application.Ports.Outbound.CampaignRepositoryPort
  alias TrafficRedirect.Domain.Model.Campaign

  def get_by_id(id) do
    case :ets.lookup(:campaigns, to_string(id)) do
      [{_id, campaign}] -> campaign
      _ -> nil
    end
  end

  def get_by_alias(alias_name) do
    case :ets.lookup(:campaign_aliases, to_string(alias_name)) do
      [{_alias, campaign}] -> campaign
      _ -> nil
    end
  end

  def save(%Campaign{} = campaign) do
    :ets.insert(:campaigns, {to_string(campaign.id), campaign})
    :ets.insert(:campaign_aliases, {to_string(campaign.alias), campaign})
    {:ok, campaign}
  end
end

defmodule TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStreamRepo do
  @moduledoc "ETS Implementation of StreamRepositoryPort"
  @behaviour TrafficRedirect.Application.Ports.Outbound.StreamRepositoryPort
  alias TrafficRedirect.Domain.Model.Stream

  def get_by_id(id) do
    case :ets.lookup(:streams, to_string(id)) do
      [{_id, stream}] -> stream
      _ -> nil
    end
  end

  def get_active_by_campaign_id(campaign_id) do
    :ets.tab2list(:streams)
    |> Enum.map(fn {_k, v} -> v end)
    |> Enum.filter(fn s -> to_string(s.campaign_id) == to_string(campaign_id) and s.is_active end)
  end

  def save(%Stream{} = stream) do
    :ets.insert(:streams, {to_string(stream.id), stream})
    {:ok, stream}
  end
end

defmodule TrafficRedirect.Infrastructure.Adapters.Storage.MemoryLandingRepo do
  @moduledoc "ETS Implementation of LandingRepositoryPort"
  @behaviour TrafficRedirect.Application.Ports.Outbound.LandingRepositoryPort
  alias TrafficRedirect.Domain.Model.Landing

  def get_by_id(id) do
    case :ets.lookup(:landings, to_string(id)) do
      [{_id, landing}] -> landing
      _ -> nil
    end
  end

  def get_by_stream_id(_stream_id) do
    :ets.tab2list(:landings)
    |> Enum.map(fn {_k, v} -> v end)
  end

  def save(%Landing{} = landing) do
    :ets.insert(:landings, {to_string(landing.id), landing})
    {:ok, landing}
  end
end

defmodule TrafficRedirect.Infrastructure.Adapters.Storage.MemoryOfferRepo do
  @moduledoc "ETS Implementation of OfferRepositoryPort"
  @behaviour TrafficRedirect.Application.Ports.Outbound.OfferRepositoryPort
  alias TrafficRedirect.Domain.Model.Offer

  def get_by_id(id) do
    case :ets.lookup(:offers, to_string(id)) do
      [{_id, offer}] -> offer
      _ -> nil
    end
  end

  def get_by_stream_id(_stream_id) do
    :ets.tab2list(:offers)
    |> Enum.map(fn {_k, v} -> v end)
  end

  def increment_conversions(offer_id) do
    case get_by_id(offer_id) do
      nil -> :ok
      %Offer{} = offer ->
        save(%{offer | conversion_count: offer.conversion_count + 1})
        :ok
    end
  end

  def save(%Offer{} = offer) do
    :ets.insert(:offers, {to_string(offer.id), offer})
    {:ok, offer}
  end
end

defmodule TrafficRedirect.Infrastructure.Adapters.Storage.MemoryDomainRepo do
  @moduledoc "ETS Implementation of DomainRepositoryPort"
  @behaviour TrafficRedirect.Application.Ports.Outbound.DomainRepositoryPort
  alias TrafficRedirect.Domain.Model.Domain

  def get_by_domain(domain_name) do
    case :ets.lookup(:domains, to_string(domain_name)) do
      [{_d, domain}] -> domain
      _ -> nil
    end
  end

  def save(%Domain{} = domain) do
    :ets.insert(:domains, {to_string(domain.domain), domain})
    {:ok, domain}
  end
end

defmodule TrafficRedirect.Infrastructure.Adapters.Storage.MemorySessionRepo do
  @moduledoc "ETS Implementation of SessionRepositoryPort"
  @behaviour TrafficRedirect.Application.Ports.Outbound.SessionRepositoryPort
  alias TrafficRedirect.Domain.Model.Session

  def get_by_visitor_code(code) do
    case :ets.lookup(:sessions, to_string(code)) do
      [{_k, session}] -> session
      _ -> nil
    end
  end

  def save(%Session{} = session) do
    :ets.insert(:sessions, {to_string(session.visitor_code), session})
    {:ok, session}
  end
end
