# Macro Engine & 39 Built-in Macros Reference 🏷️

The Macro Engine replaces placeholder tokens in landing URLs, offer URLs, actions, and postback URLs.

---

## 🔤 Syntax Rules

1. **Standard Macro:** `{subid}`, `{keyword}`, `{country}` $\rightarrow$ Replaced with URL-encoded value.
2. **Raw (Unencoded) Macro:** `{keyword!}`, `{referrer!}` $\rightarrow$ Appending `!` preserves raw unescaped characters.
3. **Macro with Argument:** `{sub_id:2}`, `{random:1000}`, `{sample:variantA|variantB}` $\rightarrow$ Colon `:` passes arguments.
4. **Fallback to Parameters:** Any `{custom_tag}` not recognized as a built-in macro automatically resolves to `conn.params["custom_tag"]`.

---

## 📋 Comprehensive Built-in Macro Catalog

| Macro Token | Raw Mode | Description | Example Output |
|---|---|---|---|
| `{subid}`, `{sub_id}` | `{subid!}` | Primary 64-bit unique Click ID | `1787855074650188872` |
| `{sub_id:1}` .. `{sub_id:10}`| — | Positional Sub-IDs | `sub_value_1` |
| `{tid}`, `{token}` | `{token!}` | Security HMAC / Gateway Token | `05a1eca669a86c81d8152fe038d1e71a` |
| `{keyword}` | `{keyword!}` | Search keyword or page title | `crypto%20trading` |
| `{source}` | `{source!}` | Traffic source parameter | `facebook_ads` |
| `{country}` | — | ISO 2-letter Country code | `US`, `DE`, `GB` |
| `{region}` | `{region!}` | GeoIP Region / State | `California` |
| `{city}` | `{city!}` | GeoIP City | `San%20Francisco` |
| `{operator}` | `{operator!}` | Mobile telecom operator | `Verizon` |
| `{connection_type}` | — | Connection type | `cellular`, `broadband` |
| `{isp}` | `{isp!}` | Internet Service Provider | `Comcast%20Cable` |
| `{device_type}` | — | Form factor | `mobile`, `desktop` |
| `{device_model}` | `{device_model!}`| Hardware model | `iPhone%2015` |
| `{os}` | — | Operating System | `iOS`, `Android`, `Windows` |
| `{os_version}` | — | OS Version | `17.4` |
| `{browser}` | — | Browser Name | `Chrome`, `Safari` |
| `{browser_version}` | — | Browser Version | `122.0` |
| `{ip}` | — | Real client IPv4 / IPv6 address | `192.168.1.1` |
| `{referrer}` | `{referrer!}` | HTTP Referer URL | `https%3A%2F%2Fgoogle.com` |
| `{se_referrer}` | `{se_referrer!}`| Search engine referrer URL | `https%3A%2F%2Fgoogle.com` |
| `{visitor_code}` | — | MD5 Fingerprint (IP + UA) | `c4ca4238a0b923820dcc509a6f75849b` |
| `{campaign_alias}` | — | Campaign URL alias | `crypto_offer_lp` |
| `{campaign_name}` | `{campaign_name!}`| Campaign display name | `Crypto%20Main` |
| `{stream_id}` | — | Selected Stream ID | `10` |
| `{stream_name}` | `{stream_name!}`| Selected Stream Name | `Main%20Stream` |
| `{traffic_source_name}` | — | Traffic source entity name | `Google%20Search` |
| `{affiliate_network_name}`| — | Affiliate network entity name | `ClickBank` |
| `{offer}`, `{offer_name}` | `{offer!}` | Selected offer name | `Alpha%20Offer` |
| `{offer_id}` | — | Selected offer ID | `101` |
| `{offer_value}` | — | Offer payout value | `25.0` |
| `{cost}` | — | CPC / CPM calculated cost | `0.15` |
| `{revenue}` | — | Recorded revenue | `25.0` |
| `{profit}` | — | Calculated profit (`revenue - cost`) | `24.85` |
| `{payout}` | — | Offer payout | `25.0` |
| `{currency}` | — | Currency code | `USD`, `EUR` |
| `{status}` | — | Conversion status | `lead`, `sale`, `rebill` |
| `{date}` | — | Current ISO 8601 Timestamp | `2026-08-27T20:55:00Z` |
| `{random:N}` | — | Random integer between 1 and $N$ | `742` |
| `{sample:A\|B\|C}` | — | Randomly selects one variant | `variantB` |
| `{current_domain}` | — | Current HTTP host domain | `tracker.example.com` |
| `{x_requested_with}` | — | X-Requested-With header value | `com.android.chrome` |
| `{debug}` | — | Debug string with subid/token | `sub_id=123&token=abc` |
| `{from_file:path}` | — | Reads content from local file | File content |
| `{conversion_cost}` | — | Conversion postback cost | `0.15` |
| `{conversion_revenue}` | — | Conversion postback revenue | `30.0` |
| `{conversion_profit}` | — | Conversion postback profit | `29.85` |
| `{conversion_time}` | — | Conversion recorded timestamp | `2026-08-27T20:55:00Z` |
