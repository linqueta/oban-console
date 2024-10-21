defmodule Oban.Console.Repo do
  def queues do
    Enum.map(Oban.config().queues, fn {name, _} ->
      [queue: name]
      |> Oban.check_queue()
      |> Map.take([:queue, :paused, :local_limit])
    end)
  end

  def pause_queue(name), do: Oban.pause_queue(queue: name)
  def resume_queue(name), do: Oban.resume_queue(queue: name)

  def all(query) do
    Oban
    |> Oban.config()
    |> Oban.Repo.all(query)
  end

  def get_job(job_id) do
    Oban
    |> Oban.config()
    |> Oban.Repo.get(Oban.Job, job_id)
  end
end
