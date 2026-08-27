defmodule TrafficRedirect.Domain.Action.Registry do
  @moduledoc """
  Extensible Action Registry supporting built-in and custom action types.
  """
  alias TrafficRedirect.Domain.Action.Actions

  @actions %{
    "http" => Actions.HttpRedirect,
    "location" => Actions.HttpRedirect,
    "js" => Actions.Js,
    "meta" => Actions.Meta,
    "double_meta" => Actions.DoubleMeta,
    "blank_referrer" => Actions.BlankReferrer,
    "iframe" => Actions.Iframe,
    "frame" => Actions.Frame,
    "curl" => Actions.Curl,
    "remote" => Actions.Remote,
    "local_file" => Actions.LocalFile,
    "show_html" => Actions.ShowHtml,
    "show_text" => Actions.ShowText,
    "echo" => Actions.ShowText,
    "sub_id" => Actions.SubId,
    "campaign" => Actions.ToCampaign,
    "group" => Actions.ToCampaign,
    "do_nothing" => Actions.DoNothing,
    "status404" => Actions.Status404,
    "formsubmit" => Actions.FormSubmit,
    "js_for_iframe" => Actions.JsForIframe,
    "js_for_script" => Actions.JsForScript
  }

  def get(name) when is_binary(name) do
    key = name |> String.downcase() |> String.trim()
    Map.get(@actions, key, Actions.HttpRedirect)
  end

  def get(_), do: Actions.HttpRedirect
end
