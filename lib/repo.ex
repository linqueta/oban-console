defmodule Oban.Console.Repo do
  import Ecto.Query

  @spec queues() :: [map()]
  def queues do
    Enum.map(Oban.config().queues, fn {name, _} ->
      [queue: name]
      |> Oban.check_queue()
      |> Map.take([:queue, :paused, :local_limit])
    end)
  end

  @spec queue_jobs() :: [{String.t(), String.t(), integer()}]
  def queue_jobs do
    all(from(j in Oban.Job, group_by: [j.queue, j.state], select: {j.queue, j.state, count(j.id)}))
  end

  @spec pause_queue(String.t()) :: :ok
  def pause_queue(name), do: Oban.pause_queue(queue: name)

  @spec resume_queue(String.t()) :: :ok
  def resume_queue(name), do: Oban.resume_queue(queue: name)

  @spec all(Ecto.Query.t()) :: [map()]
  def all(query) do
    Oban
    |> Oban.config()
    |> Oban.Repo.all(query)
  end

  @spec get_job(String.t()) :: map()
  def get_job(job_id) do
    Oban
    |> Oban.config()
    |> Oban.Repo.get(Oban.Job, job_id)
  end

  @spec cancel_job(String.t()) :: :ok
  def cancel_job(job_id), do: Oban.cancel_job(job_id)

  @spec retry_job(String.t()) :: :ok
  def retry_job(job_id), do: Oban.retry_job(job_id)
end
