defmodule TrafficRedirect.Infrastructure.ClickBufferWorkerTest do
  use ExUnit.Case, async: false
  alias TrafficRedirect.Domain.Model.RawClick
  alias TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker

  setup do
    # Clear clicks ETS table
    :ets.delete_all_objects(:clicks)
    ClickBufferWorker.flush_now()
    :ok
  end

  test "explicit flush_now/0 flushes enqueued clicks immediately into storage" do
    click = %RawClick{
      sub_id: "test_sub_flush_explicit_1",
      ip: "1.2.3.4",
      campaign_id: "camp_1"
    }

    ClickBufferWorker.enqueue(click)

    # Before flush, might not be in ETS yet (or in memory buffer)
    ClickBufferWorker.flush_now()

    # After flush, must exist in :clicks ETS table
    assert [{ "test_sub_flush_explicit_1", stored_click }] = :ets.lookup(:clicks, "test_sub_flush_explicit_1")
    assert stored_click.ip == "1.2.3.4"
  end

  test "batch size threshold (1,000 clicks) triggers immediate flush" do
    for i <- 1..1_000 do
      ClickBufferWorker.enqueue(%RawClick{
        sub_id: "batch_sub_#{i}",
        ip: "10.0.0.#{rem(i, 255)}"
      })
    end

    # Give tiny tick for GenServer cast mailbox processing
    Process.sleep(50)

    # Must all be flushed into ETS table without waiting 500ms
    assert [{ "batch_sub_1", _ }] = :ets.lookup(:clicks, "batch_sub_1")
    assert [{ "batch_sub_1000", _ }] = :ets.lookup(:clicks, "batch_sub_1000")
    assert :ets.info(:clicks, :size) >= 1_000
  end

  test "scheduled interval flush triggers automatically within 500ms" do
    click = %RawClick{
      sub_id: "timer_sub_flush_1",
      ip: "9.9.9.9",
      campaign_id: "camp_timer"
    }

    ClickBufferWorker.enqueue(click)

    # Wait for the 500ms scheduled timer to fire
    Process.sleep(600)

    # Must be in ETS table after timer fired
    assert [{ "timer_sub_flush_1", stored }] = :ets.lookup(:clicks, "timer_sub_flush_1")
    assert stored.ip == "9.9.9.9"
  end
end
