defmodule TrafficRedirect.Infrastructure.Adapters.Storage.DbInit do
  @moduledoc """
  Ensures tables and indexes exist in PostgreSQL upon boot.
  """
  alias TrafficRedirect.Infrastructure.Adapters.Storage.Repo

  def ensure_tables_exist do
    if repo_ready?() do
      query = """
      CREATE TABLE IF NOT EXISTS clicks (
        sub_id VARCHAR(64) PRIMARY KEY,
        campaign_id VARCHAR(64),
        campaign_alias VARCHAR(128),
        stream_id VARCHAR(64),
        landing_id VARCHAR(64),
        offer_id VARCHAR(64),
        affiliate_network_id VARCHAR(64),
        traffic_source_id VARCHAR(64),
        token VARCHAR(64),
        visitor_code VARCHAR(64),
        ip VARCHAR(45),
        country VARCHAR(8),
        region VARCHAR(64),
        city VARCHAR(64),
        isp VARCHAR(128),
        device_type VARCHAR(32),
        device_model VARCHAR(64),
        os VARCHAR(32),
        browser VARCHAR(32),
        cost DOUBLE PRECISION DEFAULT 0.0,
        revenue DOUBLE PRECISION DEFAULT 0.0,
        payout DOUBLE PRECISION DEFAULT 0.0,
        profit DOUBLE PRECISION DEFAULT 0.0,
        is_bot BOOLEAN DEFAULT FALSE,
        is_proxy BOOLEAN DEFAULT FALSE,
        is_unique_campaign BOOLEAN DEFAULT TRUE,
        is_unique_stream BOOLEAN DEFAULT TRUE,
        referrer TEXT,
        keyword TEXT,
        source VARCHAR(128),
        created_at TIMESTAMPTZ DEFAULT NOW()
      );
      """

      Ecto.Adapters.SQL.query(Repo, query, [])
    end
  end

  def repo_ready? do
    Process.whereis(Repo) != nil
  end
end
