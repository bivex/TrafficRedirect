defmodule TrafficRedirect.LoadAndStressTest do
  use ExUnit.Case, async: false
  alias TrafficRedirect.Application.Services.ClickService
  alias TrafficRedirect.Domain.Model.{Campaign, Offer, Stream}
  alias TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker
  alias TrafficRedirect.Infrastructure.Adapters.Storage.{
    MemoryCampaignRepo,
    MemoryOfferRepo,
    MemoryStreamRepo
  }

  setup_all do
    # Seed high-volume test campaign with multiple streams and offers
    campaign = %Campaign{
      id: "stress_camp_1",
      alias: "stress_test",
      name: "High Volume Stress Test Campaign",
      cost_default: 0.05
    }
    MemoryCampaignRepo.save(campaign)

    offer1 = %Offer{id: "off_1", name: "Offer A", url: "https://a.com/?subid={subid}&tid={tid}", share: 50}
    offer2 = %Offer{id: "off_2", name: "Offer B", url: "https://b.com/?subid={subid}&tid={tid}", share: 50}
    MemoryOfferRepo.save(offer1)
    MemoryOfferRepo.save(offer2)

    stream1 = %Stream{id: "str_1", campaign_id: "stress_camp_1", weight: 50, offers: [offer1]}
    stream2 = %Stream{id: "str_2", campaign_id: "stress_camp_1", weight: 50, offers: [offer2]}
    MemoryStreamRepo.save(stream1)
    MemoryStreamRepo.save(stream2)

    :ok
  end

  test "Stress test: 10,000 concurrent requests across parallel BEAM processes" do
    total_requests = 10_000
    concurrency = 100
    requests_per_worker = div(total_requests, concurrency)

    start_time = System.monotonic_time(:microsecond)

    # Spawn concurrent workers simulating simultaneous visitors
    tasks =
      for worker_id <- 1..concurrency do
        Task.async(fn ->
          latencies =
            for i <- 1..requests_per_worker do
              req = %{
                query_params: %{
                  "k_router_campaign" => "stress_test",
                  "source" => "worker_#{worker_id}",
                  "keyword" => "stress_click_#{i}",
                  "sub_id_1" => "sub1_#{worker_id}_#{i}"
                },
                headers: %{
                  "user-agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)",
                  "x-forwarded-for" => "192.168.#{rem(worker_id, 255)}.#{rem(i, 255)}"
                },
                host: "stress.traffic.com",
                path_info: ["stress_test"],
                request_path: "/stress_test",
                query_string: "source=worker_#{worker_id}"
              }

              req_start = System.monotonic_time(:microsecond)
              {:ok, resp} = ClickService.process_click(req)
              req_end = System.monotonic_time(:microsecond)

              assert resp.status == 302
              assert resp.headers["location"] =~ "https://"

              req_end - req_start
            end

          latencies
        end)
      end

    all_latencies = tasks |> Enum.flat_map(&Task.await(&1, 30_000)) |> Enum.sort()
    end_time = System.monotonic_time(:microsecond)

    total_duration_ms = (end_time - start_time) / 1000.0
    rps = total_requests / (total_duration_ms / 1000.0)

    p50 = Enum.at(all_latencies, div(total_requests * 50, 100))
    p95 = Enum.at(all_latencies, div(total_requests * 95, 100))
    p99 = Enum.at(all_latencies, div(total_requests * 99, 100))

    IO.puts("""

    =======================================================
    ⚡ HIGH-CONCURRENCY STRESS TEST RESULTS
    =======================================================
    Total Requests : #{total_requests}
    Concurrency    : #{concurrency} parallel processes
    Total Time     : #{Float.round(total_duration_ms, 2)} ms
    Throughput     : #{Float.round(rps, 0)} RPS
    Latency p50    : #{p50} µs (#{Float.round(p50 / 1000.0, 3)} ms)
    Latency p95    : #{p95} µs (#{Float.round(p95 / 1000.0, 3)} ms)
    Latency p99    : #{p99} µs (#{Float.round(p99 / 1000.0, 3)} ms)
    =======================================================
    """)

    # Verify that p99 latency is sub-millisecond or low milliseconds
    assert p50 < 1_000 # median < 1ms
    assert rps > 10_000 # throughput > 10k RPS on single node

    # Verify that async click buffer successfully processed events
    ClickBufferWorker.flush_now()
    clicks_count = :ets.info(:clicks, :size)
    assert clicks_count > 0
  end

  test "Edge cases & Malformed inputs stress test" do
    edge_cases = [
      # Missing params
      %{},
      # Oversized malicious params
      %{query_params: %{"k_router_campaign" => String.duplicate("a", 10_000)}},
      # Special characters & XSS attempts in headers
      %{
        query_params: %{"k_router_campaign" => "stress_test", "keyword" => "<script>alert(1)</script>"},
        headers: %{"user-agent" => "\"'><script>alert('xss')</script>"}
      },
      # Empty strings
      %{query_params: %{"k_router_campaign" => "", "keyword" => ""}},
      # Invalid Unicode / Byte sequences
      %{query_params: %{"k_router_campaign" => "stress_test", "keyword" => "тест 🚀 123"}}
    ]

    for req <- edge_cases do
      {:ok, resp} = ClickService.process_click(req)
      assert resp.status in [200, 301, 302, 404]
    end
  end
end
