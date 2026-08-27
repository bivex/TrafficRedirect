defmodule TrafficRedirect.Domain.Action.Behaviour do
  @moduledoc """
  Behaviour for redirect actions following the Strategy pattern.
  Supports contextual polymorphism: default, frame, and script.
  """
  alias TrafficRedirect.Domain.Model.{Payload, RedirectResponse}

  @callback execute(payload :: Payload.t()) :: RedirectResponse.t()
end
