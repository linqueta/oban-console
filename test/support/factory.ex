defmodule Factory do
  use ExMachina.Ecto

  @spec queue_factory(map()) :: Map.t()
  def queue_factory(attrs) do
    Map.new(attrs)
  end

  @spec job_factory(map()) :: Oban.Job.t()
  def job_factory(attrs) do
    %Oban.Job{
      state: "available",
      queue: "default",
      attempt: 1,
      worker: "ProcessOrder",
      attempted_at: ~U[2020-01-01 00:00:00Z],
      inserted_at: ~U[2020-01-01 00:00:00Z],
      scheduled_at: ~U[2020-01-01 00:00:00Z]
    }
    |> merge_attributes(attrs)
  end
end
