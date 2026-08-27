#!/usr/bin/env elixir
# Profile script: runs eprof on the full click pipeline
Mix.install([])

alias TrafficRedirect.Application.Services.ClickService
alias TrafficRedirect.Domain.Model.{Campaign, Stream, Offer, Landing}
alias TrafficRedirect.Infrastructure.Adapters.Storage.{
  MemoryCampaignRepo, MemoryStreamRepo, MemoryOfferRepo, MemoryLandingRepo
}

# Seed test data
campaign = %Campaign{id: "prof_camp", alias: "prof_alias", type: :position, name: "Profiler Campaign"}
offer    = %Offer{id: "prof_offer", name: "Prof Offer", url: "https://offer.com?sub={sub_id}&token={token}", payout: 30.0, action_type: "http", share: 100}
landing  = %Landing{id: "prof_landing", name: "Prof Landing", url: "https://landing.com/l?sub={sub_id}", action_type: "http"}
stream   = %Stream{id: "prof_stream", campaign_id: "prof_camp", name: "Main", type: :regular,
                   action_type: "http", action_payload: "https://offer.com?sub={sub_id}",
                   offers: [offer], landings: [landing], weight: 100}

MemoryCampaignRepo.save(campaign)
MemoryOfferRepo.save(offer)
MemoryLandingRepo.save(landing)
MemoryStreamRepo.save(stream)

request = %{
  headers: %{"user-agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"},
  query_params: %{"k_router_campaign" => "prof_alias", "keyword" => "crypto", "cost" => "0.15"},
  path_info: ["prof_alias"], request_path: "/prof_alias",
  query_string: "keyword=crypto&cost=0.15",
  host: "tracker.example.com", remote_ip: "93.184.216.34", scheme: "https"
}

IO.puts("\n=== Starting :eprof profiling (1000 clicks) ===\n")

:eprof.start()
:eprof.start_profiling([self()])

for _ <- 1..1_000 do
  ClickService.process_click(request)
end

:eprof.stop_profiling()
:eprof.analyze(:total)

IO.puts("\n=== :eprof profiling done ===\n")
