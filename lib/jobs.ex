defmodule Oban.Console.Jobs do
  import Ecto.Query

  alias Oban.Console.Repo
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer
  alias Oban.Console.View.Table

  @states %{
    "1" => "available",
    "2" => "scheduled",
    "3" => "retryable",
    "4" => "executing",
    "5" => "completed",
    "6" => "discarded",
    "7" => "cancelled"
  }

  @in_progress_states ~w[available scheduled retryable executing]
  @failed_states ~w[cancelled discarded]

  @spec list([Keyword.t()]) :: [Oban.Job.t()]
  def list(opts \\ []), do: Repo.all(list_query(opts))

  @spec show_list([Keyword.t()]) :: :ok
  def show_list(opts \\ []) do
    headers = [:id, :worker, :state, :queue, :attempt, :inserted_at, :attempted_at, :scheduled_at]
    opts = if opts == [], do: Storage.get_last_jobs_opts(), else: opts

    limit = Keyword.get(opts, :limit, 20) || 20
    converted_states = convert_states(Keyword.get(opts, :states, [])) || []
    ids = ids_listed_before(opts)
    sorts = Keyword.get(opts, :sorts, [%{dir: :desc, field: "id"}]) || [%{dir: :desc, field: "id"}]

    opts =
      opts
      |> Keyword.put(:ids, ids)
      |> Keyword.put(:sorts, sorts)
      |> Keyword.put(:states, converted_states)
      |> Keyword.put(:limit, limit)

    response = list(opts)
    ids = Enum.map(response, fn job -> job.id end)

    if Enum.sort(Storage.get_last_jobs_opts()) != Enum.sort(opts) do
      Storage.add_job_filter_history(opts)
    end

    Storage.set_last_jobs_ids(ids)
    Storage.set_last_jobs_opts(opts)

    filters =
      Enum.reject(opts, fn
        {_, nil} -> true
        {_, []} -> true
        {_, _} -> false
      end)

    current_time = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")

    Table.show(
      response,
      headers,
      "[#{current_time}] Rows: #{length(response)} Filters: #{inspect(filters)}"
    )
  rescue
    e ->
      Printer.red(inspect(e)) |> IO.puts()
      Storage.set_last_jobs_opts([])

      show_list()
  end

  @spec clean_storage() :: :ok
  def clean_storage, do: Storage.set_last_jobs_opts([])

  @spec debug_jobs([integer() | [integer()]]) :: :ok
  def debug_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &debug_jobs/1)
  def debug_jobs([]), do: :ok

  def debug_jobs(job_id) when is_integer(job_id) do
    case Repo.get_job(job_id) do
      nil ->
        ["Job", job_id, "Job not found"] |> Printer.error() |> IO.puts()

      job ->
        Printer.break()
        ["Job", job_id] |> Printer.title() |> IO.puts()

        # credo:disable-for-next-line
        IO.inspect(job)

        :ok
    end
  end

  def debug_jobs(job_id) do
    ["Debug", job_id, "Job ID is not valid"] |> Printer.error() |> IO.puts()
  end

  @spec retry_jobs([integer() | [integer()]]) :: :ok
  def retry_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &retry_jobs/1)
  def retry_jobs([]), do: :ok

  def retry_jobs(job_id) when is_integer(job_id) do
    Repo.retry_job(job_id)
    ["Retried", job_id] |> Printer.title() |> IO.puts()
  end

  def retry_jobs(job_id) do
    ["Retry", job_id, "Job ID is not valid"] |> Printer.error() |> IO.puts()
  end

  @spec cancel_jobs([integer() | [integer()]]) :: :ok
  def cancel_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &cancel_jobs/1)
  def cancel_jobs([]), do: :ok

  def cancel_jobs(job_id) when is_integer(job_id) do
    Repo.cancel_job(job_id)
    ["Cancelled", job_id] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs(job_id) do
    ["Cancel", job_id, "Job ID is not valid"] |> Printer.error() |> IO.puts()
  end

  defp ids_listed_before(opts) do
    case Keyword.get(opts, :ids, []) do
      nil -> []
      [0] -> Storage.get_last_jobs_ids()
      ids -> ids
    end
  end

  defp list_query(opts) do
    Oban.Job
    |> filter_by_ids(Keyword.get(opts, :ids))
    |> filter_by_states(Keyword.get(opts, :states))
    |> filter_by_queues(Keyword.get(opts, :queues))
    |> filter_by_workers(Keyword.get(opts, :workers))
    |> sort_by(Keyword.get(opts, :sorts))
    |> limit_by(Keyword.get(opts, :limit))
  end

  defp convert_states(states) do
    states
    |> Enum.map(fn
      "in_progress" -> @in_progress_states
      "failed" -> @failed_states
      state when state in ["1", "2", "3", "4", "5", "6", "7"] -> Map.get(@states, state)
      state -> state
    end)
    |> List.flatten()
  end

  defp filter_by_ids(query, nil), do: query
  defp filter_by_ids(query, []), do: query
  defp filter_by_ids(query, ids), do: where(query, [j], j.id in ^ids)

  defp filter_by_states(query, nil), do: query
  defp filter_by_states(query, []), do: query
  defp filter_by_states(query, states), do: where(query, [j], j.state in ^states)

  defp filter_by_queues(query, nil), do: query
  defp filter_by_queues(query, []), do: query
  defp filter_by_queues(query, queues), do: where(query, [j], j.queue in ^queues)

  defp filter_by_workers(query, nil), do: query
  defp filter_by_workers(query, []), do: query

  defp filter_by_workers(query, workers) do
    statements =
      Enum.reduce(workers, %{include: [], exclude: []}, fn worker, acc ->
        case String.contains?(worker, "-") do
          true -> Map.put(acc, :exclude, [String.replace("%#{worker}%", "-", "") | acc[:exclude]])
          false -> Map.put(acc, :include, ["%#{worker}%" | acc[:include]])
        end
      end)

    query
    |> apply_workers_like(statements[:include], true)
    |> apply_workers_like(statements[:exclude], false)
  end

  defp apply_workers_like(query, [], _), do: query

  defp apply_workers_like(query, workers, true) do
    dynamic_filter = false

    dynamic_filter =
      Enum.reduce(workers, dynamic_filter, fn pattern, dynamic_filter ->
        dynamic([j], like(j.worker, ^pattern) or ^dynamic_filter)
      end)

    where(query, ^dynamic_filter)
  end

  defp apply_workers_like(query, workers, false) do
    dynamic_filter = true

    dynamic_filter =
      Enum.reduce(workers, dynamic_filter, fn pattern, dynamic_filter ->
        dynamic([j], not like(j.worker, ^pattern) and ^dynamic_filter)
      end)

    where(query, ^dynamic_filter)
  end

  defp limit_by(query, nil), do: limit(query, 20)
  defp limit_by(query, limit), do: limit(query, ^limit)

  defp sort_by(query, nil), do: query
  defp sort_by(query, []), do: query

  defp sort_by(query, sorts) do
    Enum.reduce(sorts, query, fn sort, query -> sort_by_single(query, sort) end)
  end

  defp sort_by_single(query, %{dir: direction, field: selected_field}) do
    parsed_field = String.to_atom(selected_field)

    case direction do
      :asc -> order_by(query, [j], asc: field(j, ^parsed_field))
      :desc -> order_by(query, [j], desc: field(j, ^parsed_field))
    end
  end
end
