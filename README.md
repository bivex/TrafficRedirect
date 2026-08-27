# TrafficRedirect Engine 🚀

High-performance, fault-tolerant **Traffic Distribution and Redirection Engine** built with **Elixir / OTP**, **Bandit**, and **Hexagonal Architecture (Ports & Adapters) / DDD**.

Designed for high-throughput AdTech environments requiring **sub-millisecond redirection latency ($< 0.1$ ms median)** and capable of processing **$135,000+$ requests per second** on a single node without blocking redirects on database writes.

---

## ⚡ Performance Benchmarks

### 1. In-Engine BEAM Concurrency Benchmarks
Measured on 10,000 concurrent requests across 100 parallel BEAM worker processes:

| Metric | Result |
|---|---|
| **Throughput** | **$128,000 – 149,000$ RPS** |
| **Median Latency (p50)** | **$85 – 135\ \mu\text{s}$ ($< 0.14\text{ ms}$)** |
| **95th Percentile (p95)** | **$1.9 – 2.5\text{ ms}$** |
| **99th Percentile (p99)** | **$3.1 – 4.7\text{ ms}$** |
| **Database Read on Click** | **0 (Zero)** — In-memory lock-free ETS cache |
| **Click Persistence Impact** | **0 ms** — Non-blocking in-memory batch buffer (`ClickBufferWorker`) |

### 2. Docker Container Live HTTP Benchmarks (`wrk`)
Measured against the containerized production OTP release (`traffic_redirect:latest` on Alpine Linux) over real HTTP/1.1 TCP connections:

| Route / Scenario | Concurrency | Requests / Sec (RPS) | Latency (p50) | Latency (p99) | Status |
|---|---|---|---|---|---|
| **Main Click $\rightarrow$ Redirect (`/{alias}`)** | 100 connections (10 threads) | **$19,530\text{ RPS}$** | $4.79\text{ ms}$ | $17.28\text{ ms}$ | ✅ 100% 302 Found |
| **Click API v1 (`/click_api/v1`)** | 100 connections (10 threads) | **$18,133\text{ RPS}$** | $4.99\text{ ms}$ | $96.00\text{ ms}$ | ✅ 100% 200 OK |
| **Healthcheck (`/ping`)** | 100 connections (10 threads) | **$27,221\text{ RPS}$** | $3.10\text{ ms}$ | $32.14\text{ ms}$ | ✅ 100% 200 OK |
| **High Load Redirect (`/{alias}`)** | 200 connections (12 threads) | **$17,853\text{ RPS}$** | $10.17\text{ ms}$ | $48.69\text{ ms}$ | ✅ 100% 302 Found |
| **Total Processed Requests** | — | **$> 800,000$ reqs** | — | — | **0 Errors / 0 Timeouts** |

---

## 💧 DPX-Elixir Architectural Compliance & Audit

The codebase is audited by **DPX-Elixir** (Hexagonal Pattern & Architecture Detector for Elixir/OTP):

| Metric | DPX Audit Result |
|---|:---:|
| **Files Scanned** | `42` |
| **Total Architectural Patterns** | **`31` Active Patterns** |
| **⚠️ Violations / Smells** | **`0` (Zero)** |
| **KISS / Complexity Smells** | **`0` (Zero)** |
| **DRY Duplications** | **`0` (Zero)** |
| **Safety Smells (`String.to_atom`, `rescue _`)** | **`0` (Zero)** |

### Detected Pattern Catalog:
* **OTP Behaviours (3)**: `GenServer` (`MemoryStorage`, `ClickBufferWorker`), `Application` lifecycle tree.
* **Structural Hexagonal Ports & Adapters (22)**: 19 `@behaviour` adapter contracts, `ETS_REGISTRY`, and `PLUG_PIPELINE` (`Router`, `Endpoint`).
* **Functional Idioms (5)**: Pure pipeline operator chains (`|>`).
* **Behavioral (1)**: Dynamic `STRATEGY_DISPATCH` for rotators.

---

## 🏗️ Architecture & Design Patterns

The engine strictly adheres to **Hexagonal Architecture (Ports & Adapters)**, **Domain-Driven Design (DDD)**, and **SOLID** principles:

```
lib/
├── traffic_redirect/
│   ├── domain/                                  # Pure domain logic (Zero external dependencies)
│   │   ├── model/                               # Entities & Value Objects (Campaign, Stream, Offer, RawClick, etc.)
│   │   ├── pipeline/                            # 30-stage abortable Click Pipeline (Chain of Responsibility)
│   │   │   ├── stages.ex                        # Stage modules (StaticServing, CheckCache, FindCampaign, etc.)
│   │   │   └── runner.ex                        # Pipeline runner with abort support
│   │   ├── filter/                              # Catalog of 26 filters in AND/OR modes (Specification Pattern)
│   │   │   ├── behaviour.ex                     # Filter behaviour contract
│   │   │   ├── helpers.ex                       # Comparison operators with clean pattern matching
│   │   │   ├── registry.ex                      # Extensible Filter Registry
│   │   │   ├── checker.ex                       # StreamFiltersChecker
│   │   │   └── filters.ex                       # 26 built-in filter implementations
│   │   ├── strategy/                            # Stream/Landing/Offer rotators (Strategy Pattern)
│   │   ├── action/                              # 18 redirect mechanisms (Factory & Context Polymorphism)
│   │   │   ├── behaviour.ex                     # Action behaviour contract
│   │   │   ├── redirect_service.ex              # HTML/JS/Meta rendering helpers
│   │   │   ├── base_helper.ex                   # URL macro resolution
│   │   │   ├── registry.ex                      # Extensible Action Registry
│   │   │   └── actions.ex                       # 18 built-in redirect actions (Http, DoubleMeta, FormSubmit, etc.)
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
│           ├── handlers.ex                      # 12 Top-Level Route Handlers
│           ├── router.ex                        # Plug regex router
│           └── endpoint.ex                      # Header normalization & server headers
```

### Applied Design Patterns:
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
27. `CheckSendingToAnotherCampaignStage` (Campaign chaining with loop prevention)
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

## 🐳 Production Deployment & Docker

### Environment Variables
| Variable | Description | Default |
|---|---|---|
| `PORT` | HTTP server listening port | `4000` |
| `GATEWAY_SECRET` | Secret key for DoubleMeta JWT token derivation | `traffic_redirect_prod_secret_key` |
| `DISABLE_STATS` | Disable click persistence queue | `false` |
| `FORCE_SSL` | Force 301 HTTPS redirects | `false` |

### Docker Build & Run
```bash
# Build production multi-stage Alpine release image
docker build -t traffic_redirect:latest .

# Run container
docker run -d -p 4000:4000 \
  -e PORT=4000 \
  -e GATEWAY_SECRET="super_secure_jwt_secret_2026" \
  --name traffic_engine \
  traffic_redirect:latest

# Run wrk benchmark against container
wrk -t10 -c100 -d10s --latency "http://localhost:4000/ping"
```

---

## 📄 License
Proprietary / All Rights Reserved.
