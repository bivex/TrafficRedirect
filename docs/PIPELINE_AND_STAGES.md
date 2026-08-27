# Click Pipeline & 30 Stages Reference ⚙️

The core routing decision is orchestrated by a 30-stage pipeline implementing the **Chain of Responsibility** pattern.

---

## 🔄 Pipeline Execution Lifecycle

```
[Raw Request] ──► Stage 1 ──► Stage 2 ──► ... ──► Stage 30 ──► [RedirectResponse]
                      │
                   abort() (Early Exit)
                      ▼
               [Immediate Response]
```

Each stage receives a `%Payload{}` struct, performs its domain mutation, and returns:
* `{:ok, %Payload{}}` — Continues to next stage.
* `{:abort, %Payload{}}` — Short-circuits pipeline and returns immediate response.

---

## 📋 Comprehensive Catalog of 30 Stages

| # | Stage Name | Purpose | Action / Short-circuit |
|---|---|---|---|
| 1 | `StaticServingStage` | Intercepts requests for local landing assets | Returns `X-Accel-Redirect` for Nginx offload |
| 2 | `CheckCacheStage` | Evaluates cache headers / caching policy | Attaches cache control headers |
| 3 | `HttpsRedirectStage` | Enforces HTTPS when `force_ssl: true` | `abort()` with 301 Permanent Redirect |
| 4 | `CheckPrefetchStage` | Cuts off browser prefetch / prerender requests | `abort()` with 204 No Content |
| 5 | `FindCampaignStage` | Resolves campaign from alias or domain mapping | Injects `%Campaign{}` into payload |
| 6 | `NoCampaignCatcherStage` | Handles unmapped aliases / catch-all | `abort()` with 404 Not Found if missing |
| 7 | `CheckBypassCacheStage` | Detects `?bypass_cache=1` | Invalidates local caching tags |
| 8 | `FillClickInformationStage` | Detects IP, GeoIP (Country, City, ISP), User-Agent (OS, Browser, Device), Bot/Proxy flags, SubIds, Cost | Initializes `%RawClick{}` with first-write-wins priority |
| 9 | `ParamsPreprocessStage` | Normalizes and sanitizes query parameter keys | Cleans up parameter map |
| 10 | `GenerateVisitorCodeStage` | Computes deterministic fingerprint (`MD5(IP + UA)`) | Sets `visitor_code` |
| 11 | `GenerateSubIdStage` | Generates 64-bit unique click identifier | Sets `sub_id` (Snowflake / Epoch integer) |
| 12 | `LoadOrCreateSessionStage` | Loads existing visitor session from ETS storage | Sets `%Session{}` |
| 13 | `CheckParamAliasesStage` | Maps alias names (`kw` $\rightarrow$ `keyword`, etc.) | Remaps incoming query parameters |
| 14 | `UpdateCampaignUniquenessStage` | Evaluates if visitor is unique to this campaign | Updates `is_unique_campaign` boolean |
| 15 | `ChooseStreamStage` | Selects stream in order: `FORCED` $\rightarrow$ `REGULAR` $\rightarrow$ `DEFAULT` | Evaluates 26 stream filters |
| 16 | `ApplyStreamActionStage` | Applies stream-level action overrides | Configures action type |
| 17 | `UpdateStreamUniquenessStage` | Evaluates if visitor is unique to this stream | Updates `is_unique_stream` boolean |
| 18 | `ChooseLandingStage` | Selects landing page using weighted rotator or visitor binding | Injects `%Landing{}` |
| 19 | `ChooseOfferStage` | Selects affiliate offer using weight / capacity caps / explicit `?offer_id=` | Injects `%Offer{}` |
| 20 | `GenerateTokenStage` | Generates HMAC security token for double-meta & tracking | Sets `token` |
| 21 | `FindAffiliateNetworkStage` | Looks up affiliate network entity | Injects `%AffiliateNetwork{}` |
| 22 | `UpdateHitLimitStage` | Checks and increments campaign/stream daily hit caps | Aborts to fallback if limit reached |
| 23 | `UpdateCostsStage` | Computes CPC/CPM/CPA click cost based on traffic source rules | Sets `cost` |
| 24 | `UpdatePayoutStage` | Sets estimated revenue / payout from chosen Offer | Sets `payout` and `profit` |
| 25 | `PrepareRawClickToStoreStage` | Finalizes all fields of `%RawClick{}` struct | Prepares persistence DTO |
| 26 | `SaveSessionStage` | Updates visitor session in ETS repository | Persists `%Session{}` |
| 27 | `CheckSendingToAnotherCampaignStage`| Handles campaign chaining (`to_campaign`) with loop detection | Switches target campaign if configured |
| 28 | `UpdateTokenStage` | Persists token-to-click mapping | Enables secure token verification |
| 29 | `ExecuteActionStage` | Renders the final redirection payload | Executes 1 of 18 Action handlers |
| 30 | `SaveRawClicksStage` | Enqueues raw click into non-blocking batch buffer | Calls `ClickBufferWorker.enqueue/1` |
