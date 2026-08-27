defmodule TrafficRedirect.Domain.Model.Campaign do
  @moduledoc """
  Campaign aggregate root.
  Contains settings for traffic routing, schemes, visitor binding, and uniqueness.
  """
  @enforce_keys [:id, :alias]
  defstruct [
    :id,
    :alias,
    :name,
    :traffic_source_id,
    type: :position,
    scheme: :landings_offers,
    bind_visitors: false,
    cookies_ttl: 86400,
    uniqueness_method: :ip,
    uniqueness_period: 86400,
    cost_auto: false,
    cost_currency: "USD",
    cost_default: 0.0,
    parameters: %{},
    extra_params: %{},
    is_active: true,
    created_at: nil,
    updated_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t() | integer(),
          alias: String.t(),
          name: String.t() | nil,
          traffic_source_id: String.t() | integer() | nil,
          type: :position | :weight,
          scheme: :direct | :landings | :offers | :landings_offers,
          bind_visitors: boolean(),
          cookies_ttl: non_neg_integer(),
          uniqueness_method: :ip | :cookie | :ip_and_cookie | :fingerprint,
          uniqueness_period: non_neg_integer(),
          cost_auto: boolean(),
          cost_currency: String.t(),
          cost_default: float(),
          parameters: map(),
          extra_params: map(),
          is_active: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }
end

defmodule TrafficRedirect.Domain.Model.StreamFilter do
  @moduledoc """
  Value object representing a single filter attached to a Stream.
  """
  @enforce_keys [:name]
  defstruct [
    :name,
    mode: :is,
    payload: [],
    options: %{}
  ]

  @type mode :: :is | :is_not | :in | :not_in | :greater | :less | :regex
  @type t :: %__MODULE__{
          name: String.t(),
          mode: mode(),
          payload: list() | String.t() | map(),
          options: map()
        }
end

defmodule TrafficRedirect.Domain.Model.Stream do
  @moduledoc """
  Stream entity belonging to a Campaign.
  Defines routing rules, filters, weights, and action execution.
  """
  @enforce_keys [:id, :campaign_id]
  defstruct [
    :id,
    :campaign_id,
    :name,
    type: :regular,
    position: 1,
    weight: 100,
    filter_or: false,
    collect_clicks: true,
    action_type: "http",
    action_payload: nil,
    action_options: %{},
    scheme: :landings_offers,
    landings: [],
    offers: [],
    filters: [],
    is_active: true
  ]

  @type stream_type :: :forced | :regular | :default
  @type t :: %__MODULE__{
          id: String.t() | integer(),
          campaign_id: String.t() | integer(),
          name: String.t() | nil,
          type: stream_type(),
          position: integer(),
          weight: integer(),
          filter_or: boolean(),
          collect_clicks: boolean(),
          action_type: String.t(),
          action_payload: any(),
          action_options: map(),
          scheme: :direct | :landings | :offers | :landings_offers,
          landings: list(map()),
          offers: list(map()),
          filters: list(TrafficRedirect.Domain.Model.StreamFilter.t()),
          is_active: boolean()
        }
end

defmodule TrafficRedirect.Domain.Model.Landing do
  @moduledoc """
  Landing page entity.
  """
  @enforce_keys [:id]
  defstruct [
    :id,
    :name,
    :url,
    :local_path,
    type: :external,
    action_type: "http",
    action_payload: nil,
    action_options: %{},
    share: 100,
    is_active: true
  ]

  @type t :: %__MODULE__{
          id: String.t() | integer(),
          name: String.t() | nil,
          url: String.t() | nil,
          local_path: String.t() | nil,
          type: :external | :local,
          action_type: String.t(),
          action_payload: any(),
          action_options: map(),
          share: integer(),
          is_active: boolean()
        }
end

defmodule TrafficRedirect.Domain.Model.Offer do
  @moduledoc """
  Offer page entity.
  """
  @enforce_keys [:id]
  defstruct [
    :id,
    :name,
    :url,
    :affiliate_network_id,
    action_type: "http",
    action_payload: nil,
    action_options: %{},
    payout: 0.0,
    payout_currency: "USD",
    payout_auto: false,
    share: 100,
    daily_cap: nil,
    conversion_count: 0,
    is_active: true
  ]

  @type t :: %__MODULE__{
          id: String.t() | integer(),
          name: String.t() | nil,
          url: String.t() | nil,
          affiliate_network_id: String.t() | integer() | nil,
          action_type: String.t(),
          action_payload: any(),
          action_options: map(),
          payout: float(),
          payout_currency: String.t(),
          payout_auto: boolean(),
          share: integer(),
          daily_cap: non_neg_integer() | nil,
          conversion_count: non_neg_integer(),
          is_active: boolean()
        }
end

defmodule TrafficRedirect.Domain.Model.AffiliateNetwork do
  @moduledoc """
  Affiliate Network entity.
  """
  @enforce_keys [:id]
  defstruct [
    :id,
    :name,
    :postback_url,
    :offer_param,
    is_active: true
  ]

  @type t :: %__MODULE__{
          id: String.t() | integer(),
          name: String.t() | nil,
          postback_url: String.t() | nil,
          offer_param: String.t() | nil,
          is_active: boolean()
        }
end

defmodule TrafficRedirect.Domain.Model.TrafficSource do
  @moduledoc """
  Traffic Source entity.
  """
  @enforce_keys [:id]
  defstruct [
    :id,
    :name,
    :postback_url,
    parameters: %{},
    is_active: true
  ]

  @type t :: %__MODULE__{
          id: String.t() | integer(),
          name: String.t() | nil,
          postback_url: String.t() | nil,
          parameters: map(),
          is_active: boolean()
        }
end

defmodule TrafficRedirect.Domain.Model.Domain do
  @moduledoc """
  Domain mapping entity.
  """
  @enforce_keys [:domain]
  defstruct [
    :domain,
    :default_campaign_id,
    :ssl_enabled,
    is_active: true
  ]

  @type t :: %__MODULE__{
          domain: String.t(),
          default_campaign_id: String.t() | integer() | nil,
          ssl_enabled: boolean(),
          is_active: boolean()
        }
end
