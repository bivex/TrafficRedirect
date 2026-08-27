# Architecture Documentation 🏛️

The **TrafficRedirect Engine** is architected according to **Hexagonal Architecture (Ports and Adapters)**, **Domain-Driven Design (DDD)**, and **Erlang/OTP Supervision Principles**.

---

## 🔷 High-Level Architecture Overview

```
                                [ Incoming HTTP / TCP Request ]
                                              │
                                              ▼
                    ┌──────────────────────────────────────────────────┐
                    │            INFRASTRUCTURE / WEB LAYER            │
                    │  Bandit HTTP Server ──► Endpoint ──► Router      │
                    └─────────────────────────┬────────────────────────┘
                                              │ Plug.Conn -> DTO
                                              ▼
                    ┌──────────────────────────────────────────────────┐
                    │                APPLICATION LAYER                 │
                    │  ClickService / ClickApiService / PostbackService│
                    │        (Inbound Ports: ProcessClickPort)         │
                    └─────────────────────────┬────────────────────────┘
                                              │ Domain Models
                                              ▼
                    ┌──────────────────────────────────────────────────┐
                    │                   DOMAIN LAYER                   │
                    │  - 30-Stage Click Pipeline (Chain of Resp.)      │
                    │  - 26 Stream Filter Specifications               │
                    │  - 18 Contextual Redirect Actions                │
                    │  - 39 Macro Resolution Engine                    │
                    │  - Pure Domain Entities & Value Objects          │
                    └─────────────────────────┬────────────────────────┘
                                              │ Driven Outbound Ports
                                              ▼
                    ┌──────────────────────────────────────────────────┐
                    │           INFRASTRUCTURE / STORAGE & IO          │
                    │  - MemoryStorage (O(1) Concurrent ETS Indexes)   │
                    │  - ClickBufferWorker (Async Batch PG Ingestion)  │
                    │  - Ecto.Repo (PostgreSQL 16 High-Load WAL)       │
                    │  - Outbound HTTP Finch Pool                      │
                    └──────────────────────────────────────────────────┘
```

---

## 🧩 Hexagonal Layer Boundaries

### 1. Domain Layer (`lib/traffic_redirect/domain/`)
* **Strict Dependency Isolation:** Zero dependencies on web frameworks (Plug, Bandit) or storage frameworks (Ecto, ETS).
* **Entities & Value Objects:**
  * `Campaign`: Defines campaign alias, traffic routing scheme (`:landings_offers`, `:direct`), position rules.
  * `Stream`: Traffic distribution rules, weights, filters, and action payloads.
  * `Landing`: Pre-landing page configurations, rotation shares, and action types.
  * `Offer`: Affiliate offer payout details, capacity caps, conversion metrics.
  * `RawClick`: Immutable click snapshot containing device, geo, bot heuristics, and financial tracking data.
* **Domain Engines:**
  * `Pipeline.Runner`: Executes stages sequentially; handles early `abort()` short-circuits.
  * `Filter.StreamFiltersChecker`: Evaluates filter collections using strict boolean algebra (`AND` / `OR`).
  * `Macro.Processor`: Substring pre-checked regex engine replacing 39+ macro tags.
  * `Tracker.CodeGenerator`: Generates client-side IIFE JavaScript Tracker SDKs.

### 2. Application Layer (`lib/traffic_redirect/application/`)
* **Inbound Ports (`ports/inbound/`):**
  * `ProcessClickPort`: Entry point for processing raw visitor clicks.
  * `ProcessClickApiPort`: Entry point for programmatic JSON Click API requests.
  * `ProcessPostbackPort`: Entry point for affiliate network conversion postbacks.
  * `GetTrackerScriptPort`: Entry point for serving dynamic client tracker scripts.
* **Outbound Ports (`ports/outbound/`):**
  * `CampaignRepositoryPort`, `StreamRepositoryPort`, `LandingRepositoryPort`, `OfferRepositoryPort`.
  * `ClickQueuePort`: Non-blocking click persistence queue contract.
  * `PostbackQueuePort`: Asynchronous outbound HTTP webhook contract.

### 3. Infrastructure Layer (`lib/traffic_redirect/infrastructure/`)
* **Web Adapters (`web/`):**
  * `Endpoint`: Normalizes headers, handles keep-alive, attaches server headers.
  * `Router`: Fast regex route matching with fast-path body parsing bypass for `GET` requests.
  * `Handlers`: Translates HTTP `Plug.Conn` to Domain DTOs and sends back rendered responses.
* **Storage Adapters (`adapters/storage/`):**
  * `MemoryStorage`: Lock-free ETS tables with `$O(1)$` secondary index lookup tables (`:campaign_streams`, `:stream_landings`, `:stream_offers`).
  * `Repo` & `ClickSchema`: Ecto PostgreSQL adapter executing bulk inserts via `Repo.insert_all`.
* **Queue Adapters (`adapters/queue/`):**
  * `ClickBufferWorker`: GenServer buffering incoming clicks and performing asynchronous, non-blocking batch writes to PostgreSQL.

---

## 🛡️ Concurrency & Fault Tolerance Model (OTP)

```
TrafficRedirect.Supervisor (one_for_one)
 ├── TrafficRedirect.Infrastructure.Adapters.Storage.Repo (Ecto Pool)
 ├── TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStorage (ETS Owner)
 ├── TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker (GenServer Buffer)
 ├── TrafficRedirect.Infrastructure.Adapters.Queue.PostbackSenderWorker (GenServer Dispatcher)
 ├── TrafficRedirect.Finch (HTTP Client Connection Pool)
 └── Bandit (High-Performance HTTP Web Server)
```

1. **Lock-Free Concurrency:** Every incoming HTTP request executes in an isolated BEAM process spawned by Bandit.
2. **Zero Database Blocking on Click Path:** Clicks are read from in-memory ETS tables ($< 1\ \mu\text{s}$) and enqueued into memory buffer without blocking visitor redirects.
3. **Graceful Degradation:** If PostgreSQL is unreachable or restarts, the engine continues serving redirects at full speed using ETS in-memory fallback.
