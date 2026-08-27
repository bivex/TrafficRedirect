defmodule TrafficRedirect.Domain.Tracker.CodeGenerator do
  @moduledoc """
  Generates client-side IIFE JavaScript Tracker SDK for landing pages and pre-landers.
  Provides:
  - Global `window.TrafficTracker` & `window.KClient` APIs
  - SubID & Token persistence (localStorage + Cookies)
  - Auto CTA Link Rewriter (`{offer}`, `?return=`, `class="tr-offer"`)
  - Auto Form Hidden Input Injection (`sub_id`, `token`)
  - Second-Encounter Beaconing & Scroll/Time Engagement tracking
  - Client-side Postback & Custom Event firing
  """

  @doc """
  Generates the complete IIFE tracker script for a campaign alias.
  """
  def get_code(alias_name, options \\ %{}) do
    host = Map.get(options, :host, "")
    base_url = if host != "", do: "//#{host}/#{alias_name}", else: "/#{alias_name}"
    postback_url = if host != "", do: "//#{host}/postback", else: "/postback"

    """
    (function(window, document) {
      'use strict';

      if (window.TrafficTracker && window.TrafficTracker._initialized) {
        return;
      }

      var CONFIG = {
        alias: '#{alias_name}',
        baseUrl: '#{base_url}',
        postbackUrl: '#{postback_url}',
        cookiePrefix: '_tr_',
        cookieDays: 30
      };

      // --- 1. Storage Helpers (Cookie + LocalStorage + SessionStorage) ---
      var Storage = {
        getCookie: function(name) {
          var nameEQ = CONFIG.cookiePrefix + name + '=';
          var ca = document.cookie.split(';');
          for (var i = 0; i < ca.length; i++) {
            var c = ca[i];
            while (c.charAt(0) === ' ') c = c.substring(1, c.length);
            if (c.indexOf(nameEQ) === 0) return decodeURIComponent(c.substring(nameEQ.length, c.length));
          }
          return null;
        },
        setCookie: function(name, value, days) {
          var expires = '';
          if (days) {
            var date = new Date();
            date.setTime(date.getTime() + (days * 24 * 60 * 60 * 1000));
            expires = '; expires=' + date.toUTCString();
          }
          document.cookie = CONFIG.cookiePrefix + name + '=' + encodeURIComponent(value || '') + expires + '; path=/; SameSite=Lax';
        },
        get: function(key) {
          try {
            var val = window.localStorage ? localStorage.getItem(CONFIG.cookiePrefix + key) : null;
            if (val) return val;
          } catch(e) {}
          return this.getCookie(key) || '';
        },
        set: function(key, value) {
          try {
            if (window.localStorage) localStorage.setItem(CONFIG.cookiePrefix + key, value);
          } catch(e) {}
          this.setCookie(key, value, CONFIG.cookieDays);
        }
      };

      // --- 2. URL & Parameter Utilities ---
      var Utils = {
        parseQuery: function(url) {
          var query = {};
          var queryString = (url || window.location.search).split('?')[1] || '';
          var pairs = queryString.split('&');
          for (var i = 0; i < pairs.length; i++) {
            if (!pairs[i]) continue;
            var parts = pairs[i].split('=');
            query[decodeURIComponent(parts[0])] = decodeURIComponent(parts[1] || '');
          }
          return query;
        },
        buildQuery: function(params) {
          var query = [];
          for (var k in params) {
            if (params.hasOwnProperty(k) && params[k] !== undefined && params[k] !== null && params[k] !== '') {
              query.push(encodeURIComponent(k) + '=' + encodeURIComponent(params[k]));
            }
          }
          return query.join('&');
        },
        sendBeacon: function(url, data) {
          var fullUrl = url + (url.indexOf('?') === -1 ? '?' : '&') + Utils.buildQuery(data);
          if (navigator.sendBeacon) {
            try {
              navigator.sendBeacon(fullUrl);
              return;
            } catch(e) {}
          }
          var img = new Image(1, 1);
          img.src = fullUrl;
        }
      };

      // --- 3. Core Tracker State & Initialization ---
      var queryParams = Utils.parseQuery();
      var subId = queryParams.sub_id || queryParams.subid || queryParams.click_id || Storage.get('sub_id') || '';
      var token = queryParams.token || queryParams.tid || Storage.get('token') || '';

      if (subId) Storage.set('sub_id', subId);
      if (token) Storage.set('token', token);

      var Tracker = {
        _initialized: true,
        alias: CONFIG.alias,
        getSubId: function() { return subId || Storage.get('sub_id'); },
        getToken: function() { return token || Storage.get('token'); },

        // Generate full offer URL with tracking parameters
        getOfferUrl: function(customParams) {
          var params = {
            'return': '1',
            'sub_id': this.getSubId(),
            'token': this.getToken(),
            '_ts': new Date().getTime()
          };
          for (var k in queryParams) {
            if (queryParams.hasOwnProperty(k) && !params.hasOwnProperty(k)) {
              params[k] = queryParams[k];
            }
          }
          if (customParams && typeof customParams === 'object') {
            for (var cp in customParams) {
              if (customParams.hasOwnProperty(cp)) params[cp] = customParams[cp];
            }
          }
          return CONFIG.baseUrl + '?' + Utils.buildQuery(params);
        },

        // Direct CTA redirect to offer
        goToOffer: function(offerId, customParams) {
          var params = customParams || {};
          if (offerId) params.offer_id = offerId;
          window.location.href = this.getOfferUrl(params);
        },

        // Client-side postback trigger (e.g. on lead submit or purchase)
        postback: function(opts) {
          var payload = {
            sub_id: this.getSubId(),
            token: this.getToken(),
            status: opts.status || 'lead',
            payout: opts.payout || opts.revenue || 0,
            currency: opts.currency || 'USD',
            tx_id: opts.tx_id || ('tx_' + new Date().getTime()),
            _ts: new Date().getTime()
          };
          Utils.sendBeacon(CONFIG.postbackUrl, payload);
        },

        // Custom event tracking
        track: function(eventName, extra) {
          var payload = {
            k_encounter: 2,
            sub_id: this.getSubId(),
            token: this.getToken(),
            event: eventName,
            page_title: document.title || '',
            landing_url: window.location.href,
            _ts: new Date().getTime()
          };
          if (extra && typeof extra === 'object') {
            for (var k in extra) {
              if (extra.hasOwnProperty(k)) payload[k] = extra[k];
            }
          }
          Utils.sendBeacon(CONFIG.baseUrl, payload);
        }
      };

      // --- 4. Auto-DOM Integration: Replace Links & Populate Forms ---
      function setupDomHooks() {
        // A. Replace Offer Links: href="{offer}", href="?return=...", or class="tr-offer" / "k-offer"
        var links = document.querySelectorAll('a[href*="{offer}"], a[href*="?return="], a.tr-offer, a.k-offer, [data-tr-offer]');
        for (var i = 0; i < links.length; i++) {
          var link = links[i];
          var offerId = link.getAttribute('data-offer-id') || null;
          link.href = Tracker.getOfferUrl(offerId ? { offer_id: offerId } : {});
        }

        // B. Populate Form Hidden Inputs: sub_id, token
        var forms = document.querySelectorAll('form');
        for (var f = 0; f < forms.length; f++) {
          var form = forms[f];
          if (!form.querySelector('input[name="sub_id"]')) {
            var inputSubId = document.createElement('input');
            inputSubId.type = 'hidden';
            inputSubId.name = 'sub_id';
            inputSubId.value = Tracker.getSubId();
            form.appendChild(inputSubId);
          }
          if (!form.querySelector('input[name="token"]')) {
            var inputToken = document.createElement('input');
            inputToken.type = 'hidden';
            inputToken.name = 'token';
            inputToken.value = Tracker.getToken();
            form.appendChild(inputToken);
          }
        }
      }

      // --- 5. Engagement & Second Encounter Beacon ---
      function initEngagementTracking() {
        // Send encounter #2 beacon
        Tracker.track('pageview', {
          se_referrer: document.referrer || '',
          default_keyword: document.title || ''
        });

        // Scroll depth tracking (25%, 50%, 75%, 100%)
        var trackedScrolls = {};
        window.addEventListener('scroll', function() {
          var scrollPercent = Math.round(((window.scrollY + window.innerHeight) / document.documentElement.scrollHeight) * 100);
          [25, 50, 75, 100].forEach(function(pct) {
            if (scrollPercent >= pct && !trackedScrolls[pct]) {
              trackedScrolls[pct] = true;
              Tracker.track('scroll_' + pct, { depth: pct });
            }
          });
        }, { passive: true });
      }

      // Execute on DOM Ready
      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', function() {
          setupDomHooks();
          initEngagementTracking();
        });
      } else {
        setupDomHooks();
        initEngagementTracking();
      }

      // Expose Public SDK
      window.TrafficTracker = Tracker;
      window.KClient = Tracker; // Aliased for Keitaro compatibility

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
