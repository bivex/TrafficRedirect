defmodule TrafficRedirect.Domain.Strategy.Stream.PositionStrategy do
  @moduledoc """
  Selects the first stream in position order that passes all filters.
  """
  alias TrafficRedirect.Domain.Filter.Checker
  alias TrafficRedirect.Domain.Model.RawClick

  def select(streams, %RawClick{} = click, context \\ %{}) do
    streams
    |> Enum.sort_by(& &1.position)
    |> Enum.find(fn stream -> Checker.passes?(stream, click, context) end)
  end
end

defmodule TrafficRedirect.Domain.Strategy.Stream.WeightStrategy do
  @moduledoc """
  Weighted random selection among streams with shuffle and recursive re-roll on filter failure.
  """
  alias TrafficRedirect.Domain.Filter.Checker
  alias TrafficRedirect.Domain.Model.RawClick

  def select([], _click, _context), do: nil

  def select(streams, %RawClick{} = click, context) do
    # Filter out inactive or zero-weight streams
    valid_streams = Enum.filter(streams, fn s -> s.is_active && s.weight > 0 end)

    if valid_streams == [] do
      nil
    else
      pick_weighted(valid_streams, click, context)
    end
  end

  defp pick_weighted([], _click, _context), do: nil

  defp pick_weighted(streams, click, context) do
    shuffled = Enum.shuffle(streams)
    total_weight = Enum.reduce(shuffled, 0, fn s, acc -> acc + s.weight end)

    if total_weight <= 0 do
      nil
    else
      rand_val = :rand.uniform(total_weight) - 1
      chosen = find_by_cumulative_weight(shuffled, rand_val, 0)

      if chosen && Checker.passes?(chosen, click, context) do
        chosen
      else
        # Re-roll without the failed stream (recursive fallback)
        remaining = List.delete(streams, chosen)
        pick_weighted(remaining, click, context)
      end
    end
  end

  defp find_by_cumulative_weight([], _rand_val, _current), do: nil

  defp find_by_cumulative_weight([stream | rest], rand_val, current) do
    next_cum = current + stream.weight
    if rand_val < next_cum do
      stream
    else
      find_by_cumulative_weight(rest, rand_val, next_cum)
    end
  end
end

defmodule TrafficRedirect.Domain.Strategy.Stream.BoundStrategy do
  @moduledoc """
  Selects the stream previously bound to the visitor's session.
  """
  alias TrafficRedirect.Domain.Filter.Checker
  alias TrafficRedirect.Domain.Model.Payload

  def select(streams, %Payload{session: session} = payload) do
    bound_stream_id = session && session.stream_id

    if bound_stream_id do
      Enum.find(streams, fn s ->
        to_string(s.id) == to_string(bound_stream_id) and
          s.is_active and
          Checker.passes?(s, payload.raw_click)
      end)
    else
      nil
    end
  end
end

defmodule TrafficRedirect.Domain.Strategy.Landing.LandingPageRotator do
  @moduledoc """
  Rotator for landing pages within a stream (LANDINGS scheme).
  Applies visitor binding and weighted share distribution.
  """
  alias TrafficRedirect.Domain.Model.Payload

  def select([], _payload), do: nil

  def select(landings, %Payload{} = payload) do
    active_landings = Enum.filter(landings, fn l -> l.is_active && (l.share || 0) > 0 end)

    if active_landings == [] do
      nil
    else
      # Check visitor binding first
      bound_landing_id = payload.session && payload.session.landing_id
      bound = bound_landing_id && Enum.find(active_landings, fn l -> to_string(l.id) == to_string(bound_landing_id) end)

      if bound do
        bound
      else
        pick_weighted_landing(active_landings)
      end
    end
  end

  defp pick_weighted_landing(landings) do
    shuffled = Enum.shuffle(landings)
    total_share = Enum.reduce(shuffled, 0, fn l, acc -> acc + (l.share || 1) end)

    if total_share <= 0 do
      List.first(landings)
    else
      rand_val = :rand.uniform(total_share) - 1
      find_by_cumulative_share(shuffled, rand_val, 0) || List.first(landings)
    end
  end

  defp find_by_cumulative_share([], _rand_val, _current), do: nil

  defp find_by_cumulative_share([landing | rest], rand_val, current) do
    next_cum = current + (landing.share || 1)
    if rand_val < next_cum do
      landing
    else
      find_by_cumulative_share(rest, rand_val, next_cum)
    end
  end
end

defmodule TrafficRedirect.Domain.Strategy.Offer.OfferPageRotator do
  @moduledoc """
  Rotator for offers within a stream / after LP.
  Priority: explicit ?offer_id= -> stored click offer -> visitor binding -> weighted rotation.
  Also validates daily conversion capacity caps.
  """
  alias TrafficRedirect.Domain.Model.{Offer, Payload}

  def select([], _payload), do: nil

  def select(offers, %Payload{} = payload) do
    active_offers =
      offers
      |> Enum.filter(fn o -> o.is_active && (o.share || 0) > 0 end)
      |> Enum.filter(&has_capacity?/1)

    if active_offers == [] do
      nil
    else
      # Priority 1: explicit query param ?offer_id=
      query_offer_id = get_query_offer_id(payload)
      explicit_offer = query_offer_id && Enum.find(active_offers, fn o -> to_string(o.id) == to_string(query_offer_id) end)

      cond do
        explicit_offer ->
          explicit_offer

        payload.raw_click && payload.raw_click.offer_id ->
          Enum.find(active_offers, fn o -> to_string(o.id) == to_string(payload.raw_click.offer_id) end) ||
            pick_weighted_offer(active_offers)

        payload.session && payload.session.offer_id ->
          Enum.find(active_offers, fn o -> to_string(o.id) == to_string(payload.session.offer_id) end) ||
            pick_weighted_offer(active_offers)

        true ->
          pick_weighted_offer(active_offers)
      end
    end
  end

  defp has_capacity?(%Offer{daily_cap: nil}), do: true
  defp has_capacity?(%Offer{daily_cap: cap, conversion_count: count}) when is_integer(cap), do: count < cap
  defp has_capacity?(_), do: true

  defp get_query_offer_id(%Payload{request: req}) when is_map(req) do
    params = Map.get(req, :query_params, %{})
    Map.get(params, "offer_id") || Map.get(params, "offer")
  end
  defp get_query_offer_id(_), do: nil

  defp pick_weighted_offer(offers) do
    shuffled = Enum.shuffle(offers)
    total_share = Enum.reduce(shuffled, 0, fn o, acc -> acc + (o.share || 1) end)

    if total_share <= 0 do
      List.first(offers)
    else
      rand_val = :rand.uniform(total_share) - 1
      find_by_cumulative_share(shuffled, rand_val, 0) || List.first(offers)
    end
  end

  defp find_by_cumulative_share([], _rand_val, _current), do: nil

  defp find_by_cumulative_share([offer | rest], rand_val, current) do
    next_cum = current + (offer.share || 1)
    if rand_val < next_cum do
      offer
    else
      find_by_cumulative_share(rest, rand_val, next_cum)
    end
  end
end
