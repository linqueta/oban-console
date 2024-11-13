defmodule ObanMock do
  import Factory

  @spec queues() :: [map()]
  def queues do
    [
      build(:queue, queue: "default", paused: true, local_limit: 10),
      build(:queue, queue: "searching", paused: false, local_limit: 15),
      build(:queue, queue: "matching", paused: true, local_limit: 20)
    ]
  end

  @spec queue_jobs() :: [{String.t(), String.t(), integer()}]
  def queue_jobs do
    [
      {"default", "available", 10},
      {"default", "executing", 5},
      {"default", "completed", 100},
      {"default", "cancelled", 3},
      {"default", "discarded", 0},
      {"searching", "executing", 0},
      {"searching", "scheduled", 0},
      {"searching", "retryable", 5},
      {"searching", "cancelled", 0},
      {"searching", "discarded", 20},
      {"matching", "available", 0},
      {"matching", "scheduled", 29},
      {"matching", "retryable", 0},
      {"matching", "completed", 40},
      {"matching", "cancelled", 0},
      {"matching", "discarded", 0}
    ]
  end

  @spec jobs() :: [Oban.Job.t()]
  def jobs do
    [:id, :worker, :state, :queue, :attempt, :inserted_at, :attempted_at, :scheduled_at]

    [
      build(:job, id: 1, state: "available"),
      build(:job, id: 2, state: "scheduled"),
      build(:job, id: 3, state: "retryable"),
      build(:job, id: 4, state: "executing"),
      build(:job, id: 5, state: "completed"),
      build(:job, id: 6, state: "discarded"),
      build(:job, id: 7, state: "cancelled")
    ]
  end
end
