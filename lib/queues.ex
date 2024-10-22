defmodule Oban.Console.Queues do
  alias Oban.Console.Repo
  alias Oban.Console.View.Printer
  alias Oban.Console.View.Table

  @spec list() :: [Oban.Queue.t()]
  def list, do: Repo.queues()

  @spec show_list() :: :ok
  def show_list do
    headers = [:queue, :paused, :local_limit]

    Table.show(list(), headers, nil)
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
