# TrafficRedirect Engine 🚀

High-performance, fault-tolerant **Traffic Distribution and Redirection Engine** built with **Elixir / OTP**, **Bandit**, and **Hexagonal Architecture (Ports & Adapters) / DDD**.

Designed for high-throughput AdTech environments requiring **sub-millisecond redirection latency ($< 0.1$ ms median)** and capable of processing **$130,000+$ requests per second** on a single node without blocking redirects on database writes.

---

## ⚡ Performance Benchmarks

Measured on a standard node with 10,000 concurrent requests across 100 parallel BEAM worker processes:

| Metric | Result |
|---|---|
| **Throughput** | **$128,000 – 135,000$ RPS** |
| **Median Latency (p50)** | **$95 – 129\ \mu\text{s}$ ($< 0.13\text{ ms}$)** |
| **95th Percentile (p95)** | **$2.5 – 3.1\text{ ms}$** |
| **99th Percentile (p99)** | **$4.6 – 4.8\text{ ms}$** |
| **Database Read on Click** | **0 (Zero)** — In-memory ETS cache |
| **Click Persistence Impact** | **0 ms** — Non-blocking in-memory batch buffer |

---

## 🏗️ Architecture & Design Patterns

The engine strictly adheres to **Hexagonal Architecture (Ports & Adapters)**, **Domain-Driven Design (DDD)**, and **SOLID** principles:

```
lib/
├── traffic_redirect/
│   ├── domain/                                  # Pure domain logic (Zero external dependencies)
│   │   ├── model/                               # Entities & Value Objects (Campaign, Stream, Offer, RawClick, etc.)
│   │   ├── pipeline/                            # 30-stage abortable Click Pipeline (Chain of Responsibility)
│   │   ├── filter/                              # Catalog of 26 filters in AND/OR modes (Specification Pattern)
│   │   ├── strategy/                            # Stream/Landing/Offer rotators (Strategy Pattern)
│   │   ├── action/                              # 18 redirect mechanisms (Factory & Context Polymorphism)
│   │   ├── macro/                               # High-speed macro substitution engine (39 built-ins)
│   │   └── tracker/                             # IIFE JavaScript tracker generator
│   │
│   ├── application/                             # Application Layer & Use Cases
│   │   ├── ports/                               # Inbound (Driving) & Outbound (Driven) Ports (@behaviour)
│   │   └── services/                            # ClickService, ClickApiService, PostbackService, TrackerScriptService
│   │
│   └── infrastructure/                          # Infrastructure Layer (Adapters)
│       ├── adapters/
│       │   ├── storage/                         # ETS In-Memory Storage Repositories (nanosecond reads)
│       │   ├── queue/                           # ClickBufferWorker (batch persistence) & PostbackSenderWorker
│       │   └── detectors/                       # GeoIP, User-Agent device parser, Bot/Proxy heuristics
│       └── web/                                 # Bandit HTTP Endpoint & 13-route Regex Router
```

### Applied Patterns:
* **Chain of Responsibility / Pipeline**: 30-stage first encounter execution with `abort()` support.
* **Strategy Pattern**: Pluggable stream selection (`Position`, `Bound`, `Weight`), landing rotation, and offer rotation.
* **Registry / Factory (Open/Closed)**: Dynamic extensible registries for Filters, Actions, and Macros.
* **Specification Pattern**: Declarative evaluation of criteria rules against incoming `RawClick` DTOs.
* **Adapter Pattern**: Decoupled mapping between `Plug.Conn` and Domain `Payload` / `RedirectResponse`.
* **Dependency Inversion (DIP)**: Application and Domain layers depend solely on Port behaviours (`@behaviour`).

---

## 🧩 Core Engine Features

### 1. Click Pipeline (30 Stages)
1. `StaticServingStage` (`X-Accel-Redirect` offload for local landing assets)
2. `CheckCacheStage` (Cache status verification)
3. `HttpsRedirectStage` (Enforce 301 HTTPS)
4. `CheckPrefetchStage` (Prefetch request cutoff)
5. `FindCampaignStage` (Alias & domain resolution)
6. `NoCampaignCatcherStage` (404 fallback)
7. `CheckBypassCacheStage` (`bypass_cache` flag)
8. `FillClickInformationStage` (First-write-wins: IP, Geo, Device, Bot, Proxy, SubIds, Cost)
9. `ParamsPreprocessStage`
10. `GenerateVisitorCodeStage` (IP + UA fingerprint)
11. `GenerateSubIdStage`
12. `LoadOrCreateSessionStage` (Visitor session state)
13. `CheckParamAliasesStage`
14. `UpdateCampaignUniquenessStage`
15. `ChooseStreamStage` (FORCED $\rightarrow$ REGULAR $\rightarrow$ DEFAULT)
16. `ApplyStreamActionStage`
17. `UpdateStreamUniquenessStage`
18. `ChooseLandingStage` (Landing weighted rotation & visitor binding)
19. `ChooseOfferStage` (Offer rotation, capacity caps, explicit `?offer_id=`)
20. `GenerateTokenStage`
21. `FindAffiliateNetworkStage`
22. `UpdateHitLimitStage`
23. `UpdateCostsStage`
24. `UpdatePayoutStage`
25. `PrepareRawClickToStoreStage`
26. `SaveSessionStage`
27. `CheckSendingToAnotherCampaign` (Campaign chaining with loop prevention)
28. `UpdateTokenStage`
29. `ExecuteActionStage` (Context-aware redirection)
30. `SaveRawClicksStage` (Asynchronous non-blocking buffer enqueue)

### 2. Stream Filters (26 Built-ins)
`AnyParam`, `Browser`, `BrowserVersion`, `City`, `ConnectionType`, `Country`, `DeviceModel`, `DeviceType`, `EmptyReferrer`, `Interval`, `Ip`, `Ipv6`, `IsBot`, `Isp`, `Language`, `Limit`, `Operator`, `Os`, `OsVersion`, `Parameter`, `Proxy`, `Referrer`, `Region`, `Schedule`, `Uniqueness`, `UserAgent`.

### 3. Redirect Actions (18 Built-ins)
* **HTTP 302** (`Location:` header)
* **JS Redirect** (`top.location` exit from frames)
* **Meta Refresh** (`<meta http-equiv="refresh">`)
* **DoubleMeta** (Two-hop gateway redirect with **HMAC-SHA256 JWT** derived from the client's `User-Agent`)
* **Blank Referrer** (`<meta name="referrer" content="no-referrer">`)
* **Iframe & Frame** (Full-screen wrappers)
* **Curl Proxy** (Server-side proxy forwarding headers)
* **FormSubmit** (Auto-POST form forwarding all query parameters)
* **SubId Pixel / JSONP** (`Tracking.response("<sub_id>")`)
* **LocalFile, ShowHtml, ShowText, ToCampaign, Status404, DoNothing**

**Contextual Polymorphism**: Each action automatically adapts its output format depending on the execution context (`default`, `frame` via `frm=frame`, or `script` via `frm=script`).

### 4. Macro Engine (39 Built-ins)
Supports argument syntax (`{sub_id:2}`), raw unencoded mode (`{keyword!}`), conversion macros, and fallback to GET query parameters:
`subid, tid, keyword, source, country, region, city, operator, connection_type, isp, device_type, device_model, os, browser, ip, referrer, se_referrer, visitor_code, campaign_alias, campaign_name, traffic_source_name, affiliate_network_name, offer, offer_id, offer_name, offer_value, cost, revenue, profit, conversion_*, status, original_status, previous_status, currency, date, random, sample, current_domain, x_requested_with, debug, from_file`.

### 5. Web Routes Table (13 Specification Routes)
| # | Route | Handler | Purpose |
|---|---|---|---|
| 1 | `/{key}/postback`, `?postback=` / `?key=` | `PostbackHandler` | Conversion tracking postbacks |
| 2 | `/ping`, `?ping=` | `PingDomainHandler` | Domain healthcheck |
| 3 | `/preview`, `?preview=` | `SitePreviewHandler` | Landing preview |
| 4 | `/license/refresh` | `RefreshLicenseHandler` | License check |
| 5 | `/click_api/v1..v4`, `/api.php` | `ClickApiHandler` | Server-to-server Click API (JSON) |
| 6 | `?return=` | `LandingOfferHandler` | Offer click from landing page |
| 7 | `/{alias}?tracker=v2` | `LegacyTrackerHandler` | Legacy JS tracker |
| 8 | `/{alias}?k_encounter=2` / `?tracker=1` | `TrackerScriptHandler` | IIFE JS Tracker script |
| 9 | `/gateway.php?frm=dm&token=...` | `GatewayRedirectHandler` | Double-meta hop |
| 10 | `/favicon.ico` | `NotFoundHandler` | 404 |
| 11 | `/robots.txt` | `RobotsHandler` | Robots disallow |
| 12 | `/{alias}` | `ClickHandler` | **Main Click $\rightarrow$ Redirect** |
| 13 | `/*` (catch-all) | `ClickHandler` | Catch-all click |

---

## 🚀 Quick Start

### Requirements
* **Elixir**: 1.20+
* **Erlang/OTP**: 29+

### Setup & Run
```bash
# 1. Fetch dependencies
mix deps.get

# 2. Compile application
mix compile

# 3. Start the server (default port 4000)
mix run --no-halt
# or in interactive mode:
iex -S mix
```

### Running Tests & Benchmarks
```bash
# Run all 49 unit, integration, and stress tests
mix test

# Run high-concurrency stress benchmark specifically
mix test test/load_and_stress_test.exs
```

---

## 🐳 Production Deployment (Docker & Releases)

### Environment Variables
| Variable | Description | Default |
|---|---|---|
| `PORT` | HTTP server listening port | `4000` |
| `GATEWAY_SECRET` | Secret key for DoubleMeta JWT token derivation | `traffic_redirect_prod_secret_key` |
| `DISABLE_STATS` | Disable click persistence queue | `false` |
| `FORCE_SSL` | Force 301 HTTPS redirects | `false` |

### Docker Build & Run
```bash
# Build production image
docker build -t traffic_redirect:latest .

# Run container
docker run -d -p 4000:4000 \
  -e PORT=4000 \
  -e GATEWAY_SECRET="super_secure_jwt_secret_2026" \
  --name traffic_engine \
  traffic_redirect:latest
```

---

## 📄 License
Proprietary / All Rights Reserved.
