# Production Deployment & Performance Tuning 🚀

---

## 🐳 Docker Compose Quickstart

The project includes an optimized multi-stage Alpine build for the Elixir release alongside tuned PostgreSQL 16.

### Start the Stack
```bash
# 1. Clone repository
git clone https://github.com/your-org/TrafficRedirect.git
cd TrafficRedirect

# 2. Build and start containers
docker compose up -d --build

# 3. Check health
curl http://localhost:4000/ping
```

---

## ⚙️ Environment Variables

| Variable | Description | Default | Recommended Production |
|---|---|---|---|
| `PORT` | Listening HTTP port | `4000` | `4000` |
| `DATABASE_URL` | PostgreSQL connection URL | `nil` | `ecto://user:pass@pg_host:5432/traffic_redirect` |
| `POOL_SIZE` | Database connection pool size | `25` | `30` – `50` |
| `GATEWAY_SECRET` | Secret key for DoubleMeta JWT token derivation | `traffic_redirect_prod_secret_key` | Random 64-char hex string |
| `DISABLE_STATS` | Disable persistence buffer | `false` | `false` |
| `FORCE_SSL` | Enforce 301 HTTPS redirects | `false` | `true` |

---

## 🐘 PostgreSQL Performance Tuning for High-Volume Ingestion

For high-throughput click tracking ($80,000+\text{ writes/sec}$), configure PostgreSQL with the following settings in `docker-compose.yml` or `postgresql.conf`:

```ini
# Asynchronous WAL commit (essential for click logging)
synchronous_commit = off

# WAL and Checkpoint buffers
wal_buffers = 64MB
checkpoint_timeout = 15min
max_wal_size = 8GB
checkpoint_completion_target = 0.9

# Memory buffers
shared_buffers = 2GB
work_mem = 32MB
random_page_cost = 1.1

# Docker shared memory
# shm_size: 1gb
```

---

## ⚡ Load Testing & Benchmarking

Run high-concurrency benchmarks using `wrk` (or `k6` / `ab`):

```bash
# 1. Healthcheck benchmark
wrk -t10 -c100 -d10s --latency "http://localhost:4000/ping"

# 2. Full 30-stage redirect with asynchronous PostgreSQL persistence
wrk -t10 -c100 -d10s --latency "http://localhost:4000/campaign_alias?keyword=test&cost=0.10"

# 3. Click API JSON endpoint
wrk -t10 -c100 -d10s --latency "http://localhost:4000/click_api/v1?alias=campaign_alias"
```

---

## 📈 Sizing Guidelines

| Target Volume | Recommended Hardware | Database Setup |
|---|---|---|
| **Up to 20,000 RPS** | 4 vCPU, 8 GB RAM | Single Node PostgreSQL (tuned) |
| **20,000 – 80,000 RPS** | 8 vCPU, 16 GB RAM | PostgreSQL with partition by day or ClickHouse |
| **80,000 – 200,000+ RPS** | Cluster of 2–3 nodes behind HAProxy / Nginx | ClickHouse or Kafka streaming buffer |
