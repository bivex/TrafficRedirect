# Filters & Redirect Actions Reference 🎯

---

## 🔍 Stream Filters Catalog (26 Built-in Specifications)

Filters determine whether an incoming visitor click matches a stream. Stream filters can be evaluated in `AND` (all must pass) or `OR` (at least one must pass) mode.

Each filter supports standard comparison modes:
* `EQUAL` / `EQUALS` / `IN`
* `NOT_EQUAL` / `NOT_IN`
* `CONTAINS` / `NOT_CONTAINS`
* `STARTS_WITH` / `ENDS_WITH`
* `GREATER_THAN` / `LESS_THAN`
* `REGEX`

### Filter List:
1. **`AnyParam`**: Checks any query parameter key/value match.
2. **`Browser`**: Matches browser name (`Chrome`, `Safari`, `Firefox`, `Edge`, `Opera`).
3. **`BrowserVersion`**: Matches major/minor browser versions with semver comparisons.
4. **`City`**: GeoIP city name.
5. **`ConnectionType`**: Cellular, Broadband, Cable, Dialup.
6. **`Country`**: ISO 3166-1 alpha-2 country codes (`US`, `DE`, `GB`, `UA`).
7. **`DeviceModel`**: Hardware device model (`iPhone`, `Galaxy S23`, `Pixel 8`).
8. **`DeviceType`**: Form factor: `desktop`, `mobile`, `tablet`, `tv`, `bot`.
9. **`EmptyReferrer`**: Matches empty or absent `Referer` headers.
10. **`Interval`**: Limits clicks allowed per time interval.
11. **`Ip`**: Single IP or CIDR subnet matching (`192.168.1.0/24`).
12. **`Ipv6`**: IPv6 addresses and range matching.
13. **`IsBot`**: Anti-fraud bot heuristic detection.
14. **`Isp`**: Internet Service Provider name (e.g. `Comcast`, `Vodafone`).
15. **`Language`**: `Accept-Language` header code (`en`, `es`, `de`, `ru`).
16. **`Limit`**: Daily / total click capacity limit.
17. **`Operator`**: Mobile carrier / telecom operator.
18. **`Os`**: Operating system (`iOS`, `Android`, `Windows`, `macOS`, `Linux`).
19. **`OsVersion`**: OS version comparison (`Android >= 14`, `iOS >= 17`).
20. **`Parameter`**: Specific named query parameter value check.
21. **`Proxy`**: Detects VPN, TOR, Hosting, Datacenter, and Public Proxies.
22. **`Referrer`**: Domain or full URL pattern in HTTP Referer.
23. **`Region`**: State / province / administrative region.
24. **`Schedule`**: Day of week and hour of day scheduling matrix.
25. **`Uniqueness`**: Unique by Campaign, Stream, or Global IP within $N$ hours.
26. **`UserAgent`**: Exact or substring pattern in `User-Agent` header string.

---

## ⚡ Redirect Actions Catalog (18 Built-in Mechanisms)

Actions adapt their output according to the execution context:
* `default` $\rightarrow$ Native browser HTTP / HTML / JS redirect.
* `frame` (via `frm=frame`) $\rightarrow$ Rendered inside iframe context.
* `script` (via `frm=script`) $\rightarrow$ JavaScript payload executed in client tracker.

| # | Action Name | Mechanism | Output Behavior |
|---|---|---|---|
| 1 | **`Http`** | Standard HTTP 302 Found | `Location: <url>` header |
| 2 | **`JsRedirect`** | JavaScript `top.location` | Top frame breakout script |
| 3 | **`MetaRefresh`** | HTML Meta Tag | `<meta http-equiv="refresh" content="0;url=...">` |
| 4 | **`DoubleMeta`** | Two-hop HMAC-SHA256 Gateway | Obfuscates original traffic source referrer |
| 5 | **`BlankReferrer`** | Strips Referrer header | `<meta name="referrer" content="no-referrer">` |
| 6 | **`Iframe`** | Full-screen Iframe wrapper | Displays target offer in iframe |
| 7 | **`Frame`** | HTML Frameset wrapper | Classic frameset packaging |
| 8 | **`CurlProxy`** | Reverse HTTP proxy | Fetches remote content server-side |
| 9 | **`FormSubmit`** | Auto-submitting HTML POST Form | Auto-forwards all parameters via POST |
| 10 | **`SubIdPixel`** | Tracking Pixel Image (1x1 GIF) | Returns `image/gif` |
| 11 | **`Jsonp`** | JSONP callback wrapper | `Tracking.response("<sub_id>")` |
| 12 | **`LocalFile`** | Serves static file | Reads local landing HTML/JS/CSS |
| 13 | **`ShowHtml`** | Direct raw HTML rendering | Returns `text/html` body |
| 14 | **`ShowText`** | Direct raw plain text | Returns `text/plain` body |
| 15 | **`ToCampaign`** | Campaign redirection chain | Re-executes pipeline for another campaign |
| 16 | **`Status404`** | Drops traffic | Returns `404 Not Found` |
| 17 | **`DoNothing`** | No redirect | Returns `200 OK` empty body |
| 18 | **`Custom`** | Custom template renderer | Extensible custom action |
