defmodule TrafficRedirect.Application.Ports.Inbound.ProcessClickPort do
  @moduledoc "Inbound port for standard visitor click processing."
  alias TrafficRedirect.Domain.Model.RedirectResponse
  @callback process_click(request :: map()) :: {:ok, RedirectResponse.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Inbound.ProcessClickApiPort do
  @moduledoc "Inbound port for server-to-server Click API requests."
  alias TrafficRedirect.Domain.Model.RedirectResponse
  @callback process_click_api(version :: integer(), request :: map()) :: {:ok, RedirectResponse.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Inbound.ProcessPostbackPort do
  @moduledoc "Inbound port for receiving conversion postbacks."
  alias TrafficRedirect.Domain.Model.Conversion
  @callback process_postback(params :: map()) :: {:ok, Conversion.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Inbound.GetTrackerScriptPort do
  @moduledoc "Inbound port for generating landing page JS tracker script."
  @callback get_script(alias_name :: String.t(), options :: map()) :: String.t()
end

defmodule TrafficRedirect.Application.Ports.Outbound.CampaignRepositoryPort do
  @moduledoc "Port for Campaign persistence & cache lookup."
  alias TrafficRedirect.Domain.Model.Campaign
  @callback get_by_id(id :: any()) :: Campaign.t() | nil
  @callback get_by_alias(alias_name :: String.t()) :: Campaign.t() | nil
  @callback save(campaign :: Campaign.t()) :: {:ok, Campaign.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Outbound.StreamRepositoryPort do
  @moduledoc "Port for Stream persistence & cache lookup."
  alias TrafficRedirect.Domain.Model.Stream
  @callback get_by_id(id :: any()) :: Stream.t() | nil
  @callback get_active_by_campaign_id(campaign_id :: any()) :: list(Stream.t())
  @callback save(stream :: Stream.t()) :: {:ok, Stream.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Outbound.LandingRepositoryPort do
  @moduledoc "Port for Landing page persistence."
  alias TrafficRedirect.Domain.Model.Landing
  @callback get_by_id(id :: any()) :: Landing.t() | nil
  @callback get_by_stream_id(stream_id :: any()) :: list(Landing.t())
  @callback save(landing :: Landing.t()) :: {:ok, Landing.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Outbound.OfferRepositoryPort do
  @moduledoc "Port for Offer persistence & conversion counting."
  alias TrafficRedirect.Domain.Model.Offer
  @callback get_by_id(id :: any()) :: Offer.t() | nil
  @callback get_by_stream_id(stream_id :: any()) :: list(Offer.t())
  @callback increment_conversions(offer_id :: any()) :: :ok
  @callback save(offer :: Offer.t()) :: {:ok, Offer.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Outbound.DomainRepositoryPort do
  @moduledoc "Port for Domain-to-campaign mapping."
  alias TrafficRedirect.Domain.Model.Domain
  @callback get_by_domain(domain_name :: String.t()) :: Domain.t() | nil
  @callback save(domain :: Domain.t()) :: {:ok, Domain.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Outbound.SessionRepositoryPort do
  @moduledoc "Port for Visitor Session storage."
  alias TrafficRedirect.Domain.Model.Session
  @callback get_by_visitor_code(code :: String.t()) :: Session.t() | nil
  @callback save(session :: Session.t()) :: {:ok, Session.t()} | {:error, any()}
end

defmodule TrafficRedirect.Application.Ports.Outbound.ClickQueuePort do
  @moduledoc "Port for asynchronous non-blocking click buffer queue."
  alias TrafficRedirect.Domain.Model.RawClick
  @callback enqueue(click :: RawClick.t()) :: :ok
end

defmodule TrafficRedirect.Application.Ports.Outbound.PostbackQueuePort do
  @moduledoc "Port for asynchronous outgoing postback queue."
  @callback enqueue(postback_data :: map()) :: :ok
end

defmodule TrafficRedirect.Application.Ports.Outbound.GeoServicePort do
  @moduledoc "Port for GeoIP resolution."
  @callback lookup(ip :: String.t()) :: map()
end

defmodule TrafficRedirect.Application.Ports.Outbound.DeviceDetectorPort do
  @moduledoc "Port for User-Agent & Device resolution."
  @callback detect(user_agent :: String.t()) :: map()
end

defmodule TrafficRedirect.Application.Ports.Outbound.BotDetectorPort do
  @moduledoc "Port for Bot and Proxy detection."
  @callback detect(ua :: String.t(), ip :: String.t(), headers :: map()) :: map()
end

defmodule TrafficRedirect.Application.Ports.Outbound.HttpClientPort do
  @moduledoc "Port for making outgoing HTTP requests."
  @callback get(url :: String.t(), headers :: map()) :: {:ok, integer(), map(), binary()} | {:error, any()}
  @callback post(url :: String.t(), headers :: map(), body :: binary()) :: {:ok, integer(), map(), binary()} | {:error, any()}
end
