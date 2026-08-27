## Profile script v5 — OTP 27+ compatible, correct payload construction
Application.put_env(:traffic_redirect, :port, 4888)
Application.ensure_all_started(:traffic_redirect)

alias TrafficRedirect.Application.Services.ClickService
alias TrafficRedirect.Domain.Model.{Campaign, Stream, Offer, Landing, Payload, RawClick}
alias TrafficRedirect.Domain.Pipeline.{Runner, Stages}
alias TrafficRedirect.Infrastructure.Adapters.Storage.{
  MemoryCampaignRepo, MemoryStreamRepo, MemoryOfferRepo, MemoryLandingRepo
}

campaign = %Campaign{id: "prof_camp", alias: "prof_alias", type: :position, name: "Profiler Campaign"}
offer    = %Offer{id: "prof_offer", name: "Prof Offer", url: "https://offer.com?sub={sub_id}&token={token}", payout: 30.0, action_type: "http", share: 100}
landing  = %Landing{id: "prof_landing", name: "Prof Landing", url: "https://landing.com/l?sub={sub_id}", action_type: "http"}
stream   = %Stream{
  id: "prof_stream", campaign_id: "prof_camp", name: "Main", type: :regular,
  action_type: "http", action_payload: "https://offer.com?sub={sub_id}",
  offers: [offer], landings: [landing], weight: 100
}
MemoryCampaignRepo.save(campaign)
MemoryOfferRepo.save(offer)
MemoryLandingRepo.save(landing)
MemoryStreamRepo.save(stream)

request = %{
  headers: %{"user-agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"},
  query_params: %{"k_router_campaign" => "prof_alias", "keyword" => "crypto", "cost" => "0.15"},
  path_info: ["prof_alias"], request_path: "/prof_alias",
  query_string: "keyword=crypto&cost=0.15",
  host: "tracker.example.com", remote_ip: "93.184.216.34", scheme: "https"
}

context = %{
  campaign_repo:   TrafficRedirect.Infrastructure.Adapters.Storage.MemoryCampaignRepo,
  stream_repo:     TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStreamRepo,
  landing_repo:    TrafficRedirect.Infrastructure.Adapters.Storage.MemoryLandingRepo,
  offer_repo:      TrafficRedirect.Infrastructure.Adapters.Storage.MemoryOfferRepo,
  domain_repo:     TrafficRedirect.Infrastructure.Adapters.Storage.MemoryDomainRepo,
  session_repo:    TrafficRedirect.Infrastructure.Adapters.Storage.MemorySessionRepo,
  click_queue:     TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker,
  geo_service:     TrafficRedirect.Infrastructure.Adapters.Detectors.GeoService,
  device_detector: TrafficRedirect.Infrastructure.Adapters.Detectors.DeviceDetector,
  bot_detector:    TrafficRedirect.Infrastructure.Adapters.Detectors.BotDetector
}

base_payload = %Payload{
  request: request,
  raw_click: %RawClick{},
  context: :default,
  is_first_encounter: true,
  is_api_request: false
}

bench = fn fun, n ->
  times = for _ <- 1..n do
    {t, _} = :timer.tc(fun)
    t
  end
  sorted = Enum.sort(times)
  ln = length(sorted)
  {sorted, round(Enum.sum(times)/ln), Enum.at(sorted,round(ln*0.50)), Enum.at(sorted,round(ln*0.95)), Enum.at(sorted,round(ln*0.99))}
end

IO.puts("Warm-up (500 calls)...")
for _ <- 1..500, do: ClickService.process_click(request)
IO.puts("Done.\n")

# ═══════════════════════════════════════════════════════════════════════════
IO.puts("=== 1. Per-Stage Timing (5000 samples each) ===")
IO.puts("  #{String.pad_trailing("Stage", 30)}    avg      p50      p95      p99")
IO.puts("  " <> String.duplicate("─", 72))

stages = [
  {TrafficRedirect.Domain.Pipeline.Stages.FillClickInformationStage, "FillClickInformation"},
  {TrafficRedirect.Domain.Pipeline.Stages.GenerateVisitorCodeStage,  "GenerateVisitorCode"},
  {TrafficRedirect.Domain.Pipeline.Stages.GenerateSubIdStage,        "GenerateSubId"},
  {TrafficRedirect.Domain.Pipeline.Stages.FindCampaignStage,         "FindCampaign"},
  {TrafficRedirect.Domain.Pipeline.Stages.ChooseStreamStage,         "ChooseStream"},
  {TrafficRedirect.Domain.Pipeline.Stages.ChooseLandingStage,        "ChooseLanding"},
  {TrafficRedirect.Domain.Pipeline.Stages.ChooseOfferStage,          "ChooseOffer"},
  {TrafficRedirect.Domain.Pipeline.Stages.GenerateTokenStage,        "GenerateToken"},
]

Enum.each(stages, fn {stage, name} ->
  {_, avg, p50, p95, p99} = bench.(fn -> stage.execute(base_payload, context) end, 5_000)
  flag = if avg > 15, do: "⚠ ", else: "  "
  IO.puts("  #{flag}#{String.pad_trailing(name, 28)} #{String.pad_leading("#{avg}µs",8)} #{String.pad_leading("#{p50}µs",8)} #{String.pad_leading("#{p95}µs",8)} #{String.pad_leading("#{p99}µs",8)}")
end)

# ═══════════════════════════════════════════════════════════════════════════
IO.puts("\n=== 2. Full Pipeline E2E (10000 samples) ===")
{sorted, avg, p50, p95, p99} = bench.(fn -> ClickService.process_click(request) end, 10_000)
IO.puts("  avg=#{avg}µs  p50=#{p50}µs  p95=#{p95}µs  p99=#{p99}µs  max=#{List.last(sorted)}µs")
IO.puts("  Single-process: ~#{round(1_000_000/avg)} calls/sec")

# ═══════════════════════════════════════════════════════════════════════════
IO.puts("\n=== 3. build_context() overhead (10000 samples) ===")
# Measure cost of Application.get_env per call (called on every click)
{_, avg_ctx, _, _, _} = bench.(fn ->
  %{
    campaign_repo:   Application.get_env(:traffic_redirect, :campaign_repo, TrafficRedirect.Infrastructure.Adapters.Storage.MemoryCampaignRepo),
    stream_repo:     Application.get_env(:traffic_redirect, :stream_repo,   TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStreamRepo),
    landing_repo:    Application.get_env(:traffic_redirect, :landing_repo,  TrafficRedirect.Infrastructure.Adapters.Storage.MemoryLandingRepo),
    offer_repo:      Application.get_env(:traffic_redirect, :offer_repo,    TrafficRedirect.Infrastructure.Adapters.Storage.MemoryOfferRepo),
    domain_repo:     Application.get_env(:traffic_redirect, :domain_repo,   TrafficRedirect.Infrastructure.Adapters.Storage.MemoryDomainRepo),
    session_repo:    Application.get_env(:traffic_redirect, :session_repo,  TrafficRedirect.Infrastructure.Adapters.Storage.MemorySessionRepo),
    click_queue:     Application.get_env(:traffic_redirect, :click_queue,   TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker),
    geo_service:     Application.get_env(:traffic_redirect, :geo_service,   TrafficRedirect.Infrastructure.Adapters.Detectors.GeoService),
    device_detector: Application.get_env(:traffic_redirect, :device_detector, TrafficRedirect.Infrastructure.Adapters.Detectors.DeviceDetector),
    bot_detector:    Application.get_env(:traffic_redirect, :bot_detector,  TrafficRedirect.Infrastructure.Adapters.Detectors.BotDetector)
  }
end, 10_000)
flag = if avg_ctx > 5, do: " ⚠ CONSIDER CACHING", else: ""
IO.puts("  build_context/0 (10x Application.get_env): #{avg_ctx}µs/call#{flag}")

# ═══════════════════════════════════════════════════════════════════════════
IO.puts("\n=== 4. Macro Processor (10000 samples each) ===")
alias TrafficRedirect.Domain.Macro.Processor
ts_tmpl = "https://offer.com?sub={sub_id}&token={token}&kw={keyword}&country={country}&cost={cost}"
th_tmpl = "https://offer.com?sub={sub_id}&token={token}&kw={keyword}&country={country}&city={city}&os={os}&browser={browser}&device={device_type}&ip={ip}&ts={traffic_source_name}&offer={offer_name}&cost={cost}&revenue={revenue}&date={date}&random={random:9999999}&visitor={visitor_code}"
{_, avg_s, _, _, _} = bench.(fn -> Processor.process(ts_tmpl, base_payload) end, 10_000)
{_, avg_h, _, _, _} = bench.(fn -> Processor.process(th_tmpl, base_payload) end, 10_000)
IO.puts("  Simple ( 5 macros): #{avg_s}µs/call → #{round(1_000_000/max(avg_s,1))} calls/sec")
IO.puts("  Heavy  (16 macros): #{avg_h}µs/call → #{round(1_000_000/max(avg_h,1))} calls/sec")

# ═══════════════════════════════════════════════════════════════════════════
IO.puts("\n=== 5. ETS Lookup Speed (100k samples) ===")
[
  {:campaign_aliases, "prof_alias", "primary set HIT   "},
  {:campaigns,        "prof_camp",  "campaigns HIT     "},
  {:campaign_streams, "prof_camp",  "bag index HIT     "},
  {:sessions,         "xx_miss",    "session MISS      "},
  {:clicks,           "xx_miss",    "clicks MISS       "},
] |> Enum.each(fn {tbl, key, desc} ->
  {t, _} = :timer.tc(fn -> for _ <- 1..100_000, do: :ets.lookup(tbl, key) end)
  ns = round(t / 100_000 * 1000)
  flag = if ns > 400, do: " ⚠ SLOW", else: ""
  IO.puts("  :#{String.pad_trailing("#{tbl}", 22)} #{desc} → #{ns} ns/call#{flag}")
end)

# ═══════════════════════════════════════════════════════════════════════════
IO.puts("\n=== 6. GenServer health ===")
[
  TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker,
  TrafficRedirect.Infrastructure.Adapters.Queue.PostbackSenderWorker,
  TrafficRedirect.Infrastructure.Adapters.Storage.MemoryStorage,
] |> Enum.each(fn name ->
  pid = Process.whereis(name)
  if pid do
    info = Process.info(pid, [:message_queue_len, :heap_size, :total_heap_size, :reductions, :status])
    q    = info[:message_queue_len]
    short = name |> Module.split() |> List.last()
    flag = if q > 50, do: " ⚠ MAILBOX PRESSURE", else: ""
    IO.puts("  #{String.pad_trailing(short, 30)} mailbox=#{q}#{flag}  heap=#{info[:heap_size]}w  status=#{info[:status]}")
  end
end)

# ═══════════════════════════════════════════════════════════════════════════
IO.puts("\n=== 7. Concurrent throughput (50 procs × 2000 calls) ===")
{t_conc, _} = :timer.tc(fn ->
  1..50
  |> Enum.map(fn _ -> Task.async(fn -> for _ <- 1..2_000, do: ClickService.process_click(request) end) end)
  |> Enum.each(&Task.await(&1, 30_000))
end)
rps = round(100_000 / (t_conc / 1_000_000))
IO.puts("  100_000 calls in #{round(t_conc/1000)}ms → #{rps} calls/sec")

# ═══════════════════════════════════════════════════════════════════════════
IO.puts("\n=== 8. BEAM Memory ===")
mem = :erlang.memory()
mb = fn k -> "#{Float.round(mem[k] / 1_048_576, 1)}MB" end
IO.puts("  Total=#{mb.(:total)}  Processes=#{mb.(:processes)}  ETS=#{mb.(:ets)}  Binary=#{mb.(:binary)}  Atom=#{mb.(:atom)}")

IO.puts("\n✅ Profile complete.")
System.halt(0)
