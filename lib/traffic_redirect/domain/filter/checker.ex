defmodule TrafficRedirect.Domain.Filter.Checker do
  @moduledoc """
  StreamFiltersChecker evaluates a Stream's list of filters against a RawClick.
  Supports filter_or: AND (any failure -> reject) vs OR (any success -> pass).
  If a stream has no filters, it automatically passes.
  """
  alias TrafficRedirect.Domain.Filter.Registry
  alias TrafficRedirect.Domain.Model.{RawClick, Stream}

  @doc """
  Returns true if the stream passes all filter conditions for the given click.
  """
  def passes?(%Stream{filters: filters, filter_or: filter_or}, %RawClick{} = click, context \\ %{}) do
    case filters do
      nil -> true
      [] -> true
      filter_list ->
        if filter_or do
          Enum.any?(filter_list, fn filter -> evaluate_filter(filter, click, context) end)
        else
          Enum.all?(filter_list, fn filter -> evaluate_filter(filter, click, context) end)
        end
    end
  end

  defp evaluate_filter(filter, click, context) do
    case Registry.get(filter.name) do
      nil -> true
      module -> module.match?(filter, click, context)
    end
  end
end
