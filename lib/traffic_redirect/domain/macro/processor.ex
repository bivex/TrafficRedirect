defmodule TrafficRedirect.Domain.Macro.Registry do
  @moduledoc """
  Registry of macro resolvers following the Open/Closed principle.
  Provides resolution for 39+ built-in macros with fallback to request/custom params.
  """
  alias TrafficRedirect.Domain.Model.{Conversion, Payload, RawClick}

  @doc """
  Resolves a single macro key (with optional argument and raw flag) in the context of Payload or Conversion.
  """
  def resolve(name, arg, is_raw, %Payload{} = payload) do
    click = payload.raw_click || %RawClick{}
    campaign = payload.campaign
    stream = payload.stream
    offer = payload.offer
    req = payload.request || %{}

    val =
      case String.downcase(name) do
        key when key in ["subid", "sub_id"] ->
          if arg, do: get_sub_id(click, arg), else: click.sub_id || ""

        key when key in ["tid", "token"] ->
          click.token || ""

        "keyword" ->
          click.keyword || ""

        "source" ->
          click.source || ""

        "country" ->
          click.country || ""

        "region" ->
          click.region || ""

        "city" ->
          click.city || ""

        "operator" ->
          click.operator || ""

        "connection_type" ->
          click.connection_type || ""

        "isp" ->
          click.isp || ""

        "device_type" ->
          to_string(click.device_type || "")

        "device_model" ->
          click.device_model || ""

        "os" ->
          click.os || ""

        "os_version" ->
          click.os_version || ""

        "browser" ->
          click.browser || ""

        "browser_version" ->
          click.browser_version || ""

        "ip" ->
          click.real_remote_ip || click.ip || ""

        "referrer" ->
          click.referrer || ""

        "se_referrer" ->
          click.se_referrer || ""

        "visitor_code" ->
          click.visitor_code || ""

        "campaign_alias" ->
          (campaign && campaign.alias) || click.campaign_alias || ""

        "campaign_name" ->
          (campaign && campaign.name) || ""

        "stream_id" ->
          (stream && to_string(stream.id)) || (click.stream_id && to_string(click.stream_id)) || ""

        "stream_name" ->
          (stream && stream.name) || ""

        "traffic_source_name" ->
          (payload.traffic_source && payload.traffic_source.name) || ""

        "affiliate_network_name" ->
          (payload.affiliate_network && payload.affiliate_network.name) || ""

        key when key in ["offer", "offer_name"] ->
          (offer && offer.name) || ""

        "offer_id" ->
          (offer && to_string(offer.id)) || (click.offer_id && to_string(click.offer_id)) || ""

        "offer_value" ->
          (offer && to_string(offer.payout)) || ""

        "cost" ->
          to_string(click.cost || 0.0)

        "revenue" ->
          to_string(click.revenue || 0.0)

        "profit" ->
          to_string(click.profit || 0.0)

        "payout" ->
          to_string(click.payout || 0.0)

        "currency" ->
          click.cost_currency || "USD"

        "status" ->
          "lead"

        "date" ->
          DateTime.utc_now() |> DateTime.to_iso8601()

        "random" ->
          if arg, do: to_string(:rand.uniform(String.to_integer(arg))), else: to_string(:rand.uniform(1_000_000))

        "sample" ->
          if arg do
            items = String.split(arg, "|")
            Enum.random(items)
          else
            ""
          end

        "current_domain" ->
          Map.get(req, :host, "")

        "x_requested_with" ->
          click.x_requested_with || ""

        "debug" ->
          "sub_id=#{click.sub_id}&token=#{click.token}&country=#{click.country}"

        "from_file" ->
          if arg && File.exists?(arg), do: File.read!(arg) |> String.trim(), else: ""

        other ->
          # Check sub_ids, extra_params, custom_params, or query params
          cond do
            String.starts_with?(other, "sub_id_") or String.starts_with?(other, "subid") ->
              index = String.replace(other, ~r/^(sub_id_|subid)/, "")
              get_sub_id(click, index)

            String.starts_with?(other, "extra_param_") ->
              index = String.replace(other, "extra_param_", "")
              Map.get(click.extra_params || %{}, "extra_param_#{index}", "")

            true ->
              get_fallback_param(req, click, other)
          end
      end

    format_value(val, is_raw)
  end

  def resolve(name, _arg, is_raw, %Conversion{} = conv) do
    val =
      case String.downcase(name) do
        key when key in ["subid", "sub_id"] ->
          conv.sub_id || ""

        key when key in ["tid", "token"] ->
          conv.token || ""

        "conversion_cost" ->
          to_string(conv.cost || 0.0)

        "conversion_revenue" ->
          to_string(conv.revenue || 0.0)

        "conversion_profit" ->
          to_string(conv.profit || 0.0)

        "conversion_time" ->
          (conv.created_at && DateTime.to_iso8601(conv.created_at)) || ""

        "status" ->
          conv.status || ""

        "original_status" ->
          conv.original_status || ""

        "previous_status" ->
          conv.previous_status || ""

        "currency" ->
          conv.currency || "USD"

        "payout" ->
          to_string(conv.payout || 0.0)

        _ ->
          ""
      end

    format_value(val, is_raw)
  end

  defp get_sub_id(click, index) do
    sub_ids = click.sub_ids || %{}
    Map.get(sub_ids, "sub_id_#{index}") || Map.get(sub_ids, "subid#{index}") || Map.get(sub_ids, "#{index}") || ""
  end

  defp get_fallback_param(req, click, key) do
    query_params = Map.get(req, :query_params, %{})
    custom_params = Map.get(click, :custom_params, %{})
    Map.get(query_params, key) || Map.get(custom_params, key) || ""
  end

  defp format_value(val, true), do: to_string(val)
  defp format_value(val, false), do: URI.encode_www_form(to_string(val))
end

defmodule TrafficRedirect.Domain.Macro.Processor do
  @moduledoc """
  High-performance Macro Processor.
  Performs fast substring checks before invoking regex replacements.
  Supports syntax:
  - {macro}
  - {macro:arg}
  - {macro!} (raw mode)
  - {macro:arg!}
  - {name}
  """
  alias TrafficRedirect.Domain.Macro.Registry

  @macro_regex ~r/\{([a-zA-Z0-9_\-]+)(?::([^}!]+))?(!)?\}/

  @doc """
  Processes all macros in the template string using the provided context (Payload or Conversion).
  """
  def process(template, context) when is_binary(template) do
    # Fast exit: if no '{' or '$' exists in the template, return as is
    if not (String.contains?(template, "{") or String.contains?(template, "$")) do
      template
    else
      Regex.replace(@macro_regex, template, fn _full, name, arg, raw ->
        is_raw = raw == "!"
        arg_val = if arg == "", do: nil, else: arg
        Registry.resolve(name, arg_val, is_raw, context)
      end)
    end
  end

  def process(nil, _context), do: ""
  def process(other, _context), do: to_string(other)
end
