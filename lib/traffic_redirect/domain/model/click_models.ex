defmodule TrafficRedirect.Domain.Model.RawClick do
  @moduledoc """
  Mutable Click DTO representing all collected information about an incoming hit.
  Follows "first-write-wins" semantics for enrichment.
  """
  defstruct [
    :id,
    :sub_id,
    :token,
    :visitor_code,
    :session_id,
    :campaign_id,
    :campaign_alias,
    :traffic_source_id,
    :stream_id,
    :landing_id,
    :offer_id,
    :affiliate_network_id,
    :parent_campaign_id,
    :parent_sub_id,
    :ip,
    :ipv6,
    :real_remote_ip,
    :user_agent,
    :device_type,
    :device_model,
    :os,
    :os_version,
    :browser,
    :browser_version,
    :country,
    :region,
    :city,
    :isp,
    :operator,
    :connection_type,
    :language,
    :referrer,
    :se_referrer,
    :source,
    :se,
    :keyword,
    cost: 0.0,
    cost_currency: "USD",
    payout: 0.0,
    payout_currency: "USD",
    revenue: 0.0,
    profit: 0.0,
    is_bot: false,
    is_proxy: false,
    is_unique_campaign: true,
    is_unique_stream: true,
    is_unique_global: true,
    is_geo_resolved: false,
    is_device_resolved: false,
    is_bot_resolved: false,
    sub_ids: %{},
    extra_params: %{},
    custom_params: %{},
    x_requested_with: nil,
    created_at: nil
  ]

  @type t :: %__MODULE__{}

  @doc """
  Sets a value only if it's currently nil or empty (first-write-wins).
  """
  def put_if_nil(%__MODULE__{} = click, key, value) do
    current = Map.get(click, key)
    if is_nil(current) or current == "" do
      Map.put(click, key, value)
    else
      click
    end
  end
end

defmodule TrafficRedirect.Domain.Model.RedirectResponse do
  @moduledoc """
  Domain representation of an HTTP / API redirect result.
  Completely decoupled from runtime web server or framework.
  """
  defstruct [
    status: 302,
    headers: %{},
    body: "",
    action_type: "http",
    target_url: nil,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          status: integer(),
          headers: map(),
          body: String.t(),
          action_type: String.t(),
          target_url: String.t() | nil,
          metadata: map()
        }

  def put_header(%__MODULE__{headers: headers} = resp, key, value) do
    %{resp | headers: Map.put(headers, String.downcase(key), value)}
  end

  def redirect(url, status \\ 302) do
    %__MODULE__{
      status: status,
      headers: %{"location" => url, "content-type" => "text/html; charset=utf-8"},
      body: "Redirecting to <a href=\"#{url}\">#{url}</a>",
      action_type: "http",
      target_url: url
    }
  end

  def html(body, status \\ 200) do
    %__MODULE__{
      status: status,
      headers: %{"content-type" => "text/html; charset=utf-8"},
      body: body,
      action_type: "show_html"
    }
  end

  def javascript(script, status \\ 200) do
    %__MODULE__{
      status: status,
      headers: %{"content-type" => "application/javascript; charset=utf-8"},
      body: script,
      action_type: "js"
    }
  end

  def json(data, status \\ 200) do
    body = if is_binary(data), do: data, else: Jason.encode!(data)
    %__MODULE__{
      status: status,
      headers: %{"content-type" => "application/json; charset=utf-8"},
      body: body,
      action_type: "json"
    }
  end
end

defmodule TrafficRedirect.Domain.Model.Payload do
  @moduledoc """
  Pipeline Payload that traverses the 30 stages.
  Carries the request data, raw click, resolution context, and output response.
  """
  defstruct [
    :request,
    raw_click: %TrafficRedirect.Domain.Model.RawClick{},
    response: nil,
    campaign: nil,
    stream: nil,
    landing: nil,
    offer: nil,
    affiliate_network: nil,
    traffic_source: nil,
    session: nil,
    action_type: "http",
    action_payload: nil,
    action_options: %{},
    is_first_encounter: true,
    is_api_request: false,
    api_version: 1,
    context: :default,
    chain_count: 0,
    aborted: false,
    abort_reason: nil,
    errors: [],
    metadata: %{}
  ]

  @type context_type :: :default | :frame | :script
  @type t :: %__MODULE__{
          request: map() | nil,
          raw_click: TrafficRedirect.Domain.Model.RawClick.t(),
          response: TrafficRedirect.Domain.Model.RedirectResponse.t() | nil,
          campaign: TrafficRedirect.Domain.Model.Campaign.t() | nil,
          stream: TrafficRedirect.Domain.Model.Stream.t() | nil,
          landing: TrafficRedirect.Domain.Model.Landing.t() | nil,
          offer: TrafficRedirect.Domain.Model.Offer.t() | nil,
          affiliate_network: TrafficRedirect.Domain.Model.AffiliateNetwork.t() | nil,
          traffic_source: TrafficRedirect.Domain.Model.TrafficSource.t() | nil,
          session: map() | nil,
          action_type: String.t(),
          action_payload: any(),
          action_options: map(),
          is_first_encounter: boolean(),
          is_api_request: boolean(),
          api_version: integer(),
          context: context_type(),
          chain_count: non_neg_integer(),
          aborted: boolean(),
          abort_reason: String.t() | nil,
          errors: list(any()),
          metadata: map()
        }

  def abort(%__MODULE__{} = payload, reason \\ "Aborted") do
    %{payload | aborted: true, abort_reason: reason}
  end
end

defmodule TrafficRedirect.Domain.Model.Session do
  @moduledoc """
  Visitor session tracking entity.
  """
  @enforce_keys [:id, :visitor_code]
  defstruct [
    :id,
    :visitor_code,
    :campaign_id,
    :stream_id,
    :landing_id,
    :offer_id,
    :sub_id,
    :token,
    :ip,
    :user_agent,
    hit_count: 1,
    first_hit_at: nil,
    last_hit_at: nil,
    expires_at: nil,
    data: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          visitor_code: String.t(),
          campaign_id: String.t() | integer() | nil,
          stream_id: String.t() | integer() | nil,
          landing_id: String.t() | integer() | nil,
          offer_id: String.t() | integer() | nil,
          sub_id: String.t() | nil,
          token: String.t() | nil,
          ip: String.t() | nil,
          user_agent: String.t() | nil,
          hit_count: integer(),
          first_hit_at: DateTime.t() | nil,
          last_hit_at: DateTime.t() | nil,
          expires_at: DateTime.t() | nil,
          data: map()
        }
end

defmodule TrafficRedirect.Domain.Model.Conversion do
  @moduledoc """
  Conversion event data structure.
  """
  @enforce_keys [:sub_id]
  defstruct [
    :id,
    :sub_id,
    :token,
    :campaign_id,
    :stream_id,
    :offer_id,
    :affiliate_network_id,
    status: "lead",
    original_status: "lead",
    previous_status: nil,
    payout: 0.0,
    currency: "USD",
    cost: 0.0,
    revenue: 0.0,
    profit: 0.0,
    tx_id: nil,
    param: nil,
    is_first_conversion: true,
    created_at: nil
  ]

  @type t :: %__MODULE__{}
end
