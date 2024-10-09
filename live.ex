defmodule Oban.Console.Config do
  def oban_configured?() do
    with {_, true} <- {:installed, Code.ensure_loaded?(Oban)},
         {_, %Oban.Config{queues: [_ | _]}} <- {:configured, Oban.config()} do
      :ok
    else
      {:installed, false} ->
        {:error, "Oban is not installed"}

      {:configured, %Oban.Config{queues: []}} ->
        {:error, "Oban is installed but no queues are configured"}

      {:configured, _} ->
        {:error, "Oban isn't configured"}
    end
  end
end

defmodule Oban.Console.Queues do
  def list() do
    Enum.map(Oban.config().queues, fn {name, _} ->
      [queue: name]
      |> Oban.check_queue()
      |> Map.take([:queue, :local_limit, :global_limit, :paused, :rate_limit])
    end)
  end

  def pause(name), do: Oban.pause_queue(queue: name)

  def resume(name), do: Oban.resume_queue(queue: name)
end

defmodule Oban.Console.Jobs do
  @states ~w[available scheduled retryable executing completed cancelled discarded]
  @in_progress_states ~w[available scheduled retryable executing]
  @failed_states ~w[cancelled discarded]

  import Ecto.Query

  def list(opts \\ []) do
    query =
      Oban.Job
      |> filter_by_ids(Keyword.get(opts, :ids))
      |> filter_by_states(Keyword.get(opts, :states))
      |> filter_by_queues(Keyword.get(opts, :queues))
      |> filter_by_limit(Keyword.get(opts, :limit, 10))

    Oban
    |> Oban.config()
    |> Oban.Repo.all(query)
  end

  def retry(job_id) when is_integer(job_id), do: Oban.retry_job(job_id)
  def retry([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &Oban.retry_job/1)

  def cancel(job_id) when is_integer(job_id), do: Oban.cancel_job(job_id)
  def cancel([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &Oban.cancel_job/1)

  defp filter_by_ids(query, nil), do: query
  defp filter_by_ids(query, []), do: query
  defp filter_by_ids(query, ids), do: where(query, [j], j.id in ^ids)

  defp filter_by_states(query, nil), do: query

  defp filter_by_states(query, states) do
    selected_states =
      Enum.flat_map(states, fn
        :in_progress -> @in_progress_states
        :failed -> @failed_states
        state when is_atom(state) -> to_string(state)
        state -> state
      end)

    where(query, [j], j.state in ^selected_states)
  end

  defp filter_by_queues(query, nil), do: query
  defp filter_by_queues(query, []), do: query
  defp filter_by_queues(query, queues), do: where(query, [j], j.queue in ^queues)

  defp filter_by_limit(query, limit), do: limit(query, ^limit)
end
