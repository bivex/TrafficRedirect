defmodule TrafficRedirect.Infrastructure.Adapters.Storage.ClickSchema do
  @moduledoc """
  Ecto Schema matching the 'clicks' table for persistent storage.
  """
  use Ecto.Schema

  @primary_key false
  schema "clicks" do
    field :sub_id, :string, primary_key: true
    field :campaign_id, :string
    field :campaign_alias, :string
    field :stream_id, :string
    field :landing_id, :string
    field :offer_id, :string
    field :affiliate_network_id, :string
    field :traffic_source_id, :string
    field :token, :string
    field :visitor_code, :string
    field :ip, :string
    field :country, :string
    field :region, :string
    field :city, :string
    field :isp, :string
    field :device_type, :string
    field :device_model, :string
    field :os, :string
    field :browser, :string
    field :cost, :float, default: 0.0
    field :revenue, :float, default: 0.0
    field :payout, :float, default: 0.0
    field :profit, :float, default: 0.0
    field :is_bot, :boolean, default: false
    field :is_proxy, :boolean, default: false
    field :is_unique_campaign, :boolean, default: true
    field :is_unique_stream, :boolean, default: true
    field :referrer, :string
    field :keyword, :string
    field :source, :string
    field :created_at, :utc_datetime_usec
  end

  @doc """
  Converts a Domain.Model.RawClick struct to a map suitable for Repo.insert_all/2.
  """
  def from_raw_click(click) do
    %{
      sub_id: to_string(click.sub_id || "sub_#{System.unique_integer([:positive])}"),
      campaign_id: to_string(click.campaign_id || ""),
      campaign_alias: to_string(click.campaign_alias || ""),
      stream_id: to_string(click.stream_id || ""),
      landing_id: to_string(click.landing_id || ""),
      offer_id: to_string(click.offer_id || ""),
      affiliate_network_id: to_string(click.affiliate_network_id || ""),
      traffic_source_id: to_string(click.traffic_source_id || ""),
      token: to_string(click.token || ""),
      visitor_code: to_string(click.visitor_code || ""),
      ip: to_string(click.ip || "127.0.0.1"),
      country: to_string(click.country || "US"),
      region: to_string(click.region || ""),
      city: to_string(click.city || ""),
      isp: to_string(click.isp || ""),
      device_type: to_string(click.device_type || :desktop),
      device_model: to_string(click.device_model || ""),
      os: to_string(click.os || ""),
      browser: to_string(click.browser || ""),
      cost: click.cost || 0.0,
      revenue: click.revenue || 0.0,
      payout: click.payout || 0.0,
      profit: click.profit || 0.0,
      is_bot: click.is_bot || false,
      is_proxy: click.is_proxy || false,
      is_unique_campaign: click.is_unique_campaign || true,
      is_unique_stream: click.is_unique_stream || true,
      referrer: to_string(click.referrer || ""),
      keyword: to_string(click.keyword || ""),
      source: to_string(click.source || ""),
      created_at: click.created_at || DateTime.utc_now()
    }
  end
end
