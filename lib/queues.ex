defmodule Oban.Console.Queues do
  alias Oban.Console.Repo
  alias Oban.Console.View.Printer
  alias Oban.Console.View.Table

  @spec list() :: [Oban.Queue.t()]
  def list, do: Repo.queues()

  @spec show_list() :: :ok
  def show_list do
    headers = [
      :queue,
      :paused,
      :local_limit,
      :available,
      :executing,
      :scheduled,
      :retryable,
      :completed,
      :cancelled,
      :discarded
    ]

    queues = list()
    queue_jobs = Repo.queue_jobs()

    default = %{
      queue: nil,
      paused: false,
      local_limit: nil,
      available: 0,
      executing: 0,
      scheduled: 0,
      retryable: 0,
      completed: 0,
      cancelled: 0,
      discarded: 0
    }

    queues =
      Enum.map(queues, fn queue ->
        states =
          queue_jobs
          |> Enum.filter(fn {name, _, _} -> name == queue.queue end)
          |> Enum.map(fn {_, state, count} -> {String.to_atom(state), count} end)
          |> Map.new()

        default |> Map.merge(queue) |> Map.merge(states)
      end)

    Table.show(queues, headers, nil)
  end

  @spec pause_queues([String.t()]) :: :ok
  def pause_queues([_ | _] = names), do: Enum.each(names, &pause_queues/1)
  def pause_queues([]), do: :ok

  def pause_queues(name) when is_binary(name) do
    Repo.pause_queue(queue: name)
    ["Paused", name] |> Printer.title() |> IO.puts()
  end

  def pause_queues(name) do
    ["Pause", name, "Queue name is not valid"] |> Printer.error() |> IO.puts()
  end

  @spec resume_queues([String.t()]) :: :ok
  def resume_queues([_ | _] = names), do: Enum.each(names, &resume_queues/1)
  def resume_queues([]), do: :ok

  def resume_queues(name) when is_binary(name) do
    Repo.resume_queue(queue: name)
    ["Resumed", name] |> Printer.title() |> IO.puts()
  end

  def resume_queues(name) do
    ["Resume", name, "Queue name is not valid"] |> Printer.error() |> IO.puts()
  end
end
