defmodule TrafficRedirect.Domain.Tracker.CodeGenerator do
  @moduledoc """
  Generates client-side IIFE JavaScript Tracker for landing pages.
  Handles localStorage token caching, title/keyword detection, and second encounter beaconing.
  """

  @doc """
  Generates the IIFE tracker script for a campaign alias.
  """
  def get_code(alias_name, options \\ %{}) do
    host = Map.get(options, :host, "")
    base_url = if host != "", do: "//#{host}/#{alias_name}", else: "/#{alias_name}"

    """
    (function(window, document) {
      'use strict';
      try {
        var storageKey = 'tr_' + '#{alias_name}';
        var cachedSubId = localStorage.getItem(storageKey + '_subid') || '';
        var cachedToken = localStorage.getItem(storageKey + '_token') || '';
        var pageTitle = document.title || '';
        var pageReferrer = document.referrer || '';
        var currentUrl = window.location.href;

        var params = [
          'k_encounter=2',
          'sub_id=' + encodeURIComponent(cachedSubId),
          'token=' + encodeURIComponent(cachedToken),
          'default_keyword=' + encodeURIComponent(pageTitle),
          'se_referrer=' + encodeURIComponent(pageReferrer),
          'landing_url=' + encodeURIComponent(currentUrl),
          'bypass_cache=1',
          '_ts=' + new Date().getTime()
        ];

        var beaconUrl = '#{base_url}?' + params.join('&');
        var script = document.createElement('script');
        script.type = 'text/javascript';
        script.async = true;
        script.src = beaconUrl;

        script.onload = function() {
          // Tracker loaded and verified
        };

        var firstScript = document.getElementsByTagName('script')[0];
        if (firstScript && firstScript.parentNode) {
          firstScript.parentNode.insertBefore(script, firstScript);
        } else {
          document.head.appendChild(script);
        }
      } catch (e) {
        if (window.console && window.console.error) {
          window.console.error('Tracker error:', e);
        }
      }
    })(window, document);
    """
  end

  @doc """
  Returns base64 data-URI of the tracker script.
  """
  def get_data_uri(alias_name, options \\ %{}) do
    code = get_code(alias_name, options)
    "data:application/javascript;base64," <> Base.encode64(code)
  end
end
