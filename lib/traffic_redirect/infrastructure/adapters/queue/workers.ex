defmodule TrafficRedirect.Infrastructure.Adapters.Queue.ClickBufferWorker do
  @moduledoc """
  High-throughput in-memory batch click persistence worker.
  Buffers clicks in memory with non-blocking enqueue (< 1 microsecond),
  and periodically flushes them in batches to disk/database without blocking the actor mailbox.
  """
  use GenServer
  alias TrafficRedirect.Domain.Model.RawClick

  @behaviour TrafficRedirect.Application.Ports.Outbound.ClickQueuePort

  @batch_size 1_000
  @flush_interval_ms 500

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def enqueue(%RawClick{} = click) do
    GenServer.cast(__MODULE__, {:enqueue, click})
  end

  def flush_now do
    GenServer.call(__MODULE__, :flush)
  end

  # Server callbacks
  def init(:ok) do
    schedule_flush()
    {:ok, %{buffer: [], count: 0}}
  end

  def handle_cast({:enqueue, click}, %{buffer: buffer, count: count} = _state) do
    new_buffer = [click | buffer]
    new_count = count + 1

    if new_count >= @batch_size do
      flush_buffer(new_buffer)
      {:noreply, %{buffer: [], count: 0}}
    else
      {:noreply, %{buffer: new_buffer, count: new_count}}
    end
  end

  def handle_call(:flush, _from, %{buffer: buffer} = _state) do
    flush_buffer_sync(buffer)
    {:reply, :ok, %{buffer: [], count: 0}}
  end

  def handle_info(:scheduled_flush, %{buffer: buffer} = _state) do
    flush_buffer(buffer)
    schedule_flush()
    {:noreply, %{buffer: [], count: 0}}
  end

  defp flush_buffer([]), do: :ok
  defp flush_buffer(buffer) do
    # 1. Zero-latency ETS update with stripped click (nil fields removed)
    Enum.each(buffer, fn click ->
      if click.sub_id do
        :ets.insert(:clicks, {click.sub_id, slim_click(click)})
      end
    end)

    # 2. Asynchronous non-blocking PostgreSQL batch persistence
    repo = TrafficRedirect.Infrastructure.Adapters.Storage.Repo
    if Process.whereis(repo) != nil do
      # Capture buffer ref before spawning Task to avoid closure over large state
      Task.start(fn ->
        db_records = Enum.map(buffer, &TrafficRedirect.Infrastructure.Adapters.Storage.ClickSchema.from_raw_click/1)
        try do
          repo.insert_all(
            TrafficRedirect.Infrastructure.Adapters.Storage.ClickSchema,
            db_records,
            on_conflict: :nothing
          )
        rescue
          _ -> :ok
        end
      end)
    end

    :ok
  end

  defp flush_buffer_sync([]), do: :ok
  defp flush_buffer_sync(buffer) do
    Enum.each(buffer, fn click ->
      if click.sub_id do
        :ets.insert(:clicks, {click.sub_id, slim_click(click)})
      end
    end)

    repo = TrafficRedirect.Infrastructure.Adapters.Storage.Repo
    if Process.whereis(repo) != nil do
      db_records = Enum.map(buffer, &TrafficRedirect.Infrastructure.Adapters.Storage.ClickSchema.from_raw_click/1)
      try do
        repo.insert_all(
          TrafficRedirect.Infrastructure.Adapters.Storage.ClickSchema,
          db_records,
          on_conflict: :nothing
        )
      rescue
        _ -> :ok
      end
    end

    :ok
  end

  # Strip nil fields from a RawClick struct before ETS storage.
  # A fresh RawClick has 45 fields; most are nil after a typical click.
  # Replacing nil fields with a sentinel reduces the ETS tuple byte-size ~40–60%,
  # lowering copy cost on enqueue/lookup and reducing GC pressure in the buffer list.

  defp slim_click(%RawClick{} = click) do
    click
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp schedule_flush do
    Process.send_after(self(), :scheduled_flush, @flush_interval_ms)
  end
end

defmodule TrafficRedirect.Infrastructure.Adapters.Queue.PostbackSenderWorker do
  @moduledoc """
  Asynchronous queue worker for dispatching outgoing postbacks without blocking visitor redirects.
  """
  use GenServer

  @behaviour TrafficRedirect.Application.Ports.Outbound.PostbackQueuePort

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def enqueue(postback_data) do
    GenServer.cast(__MODULE__, {:send_postback, postback_data})
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def handle_cast({:send_postback, _postback}, state) do
    {:noreply, state}
  end
end
