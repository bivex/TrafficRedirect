defmodule TrafficRedirect.Domain.Filter.Behaviour do
  @moduledoc """
  Filter behaviour (Specification Pattern) for evaluating stream criteria against RawClick.
  """
  alias TrafficRedirect.Domain.Model.{RawClick, StreamFilter}

  @callback match?(filter :: StreamFilter.t(), click :: RawClick.t(), context :: map()) :: boolean()
end
