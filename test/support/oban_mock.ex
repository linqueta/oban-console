defmodule ObanMock do
  import Factory

  def queues do
    [
      build(:queue, queue: "default", paused: true, local_limit: 10),
      build(:queue, queue: "searching", paused: false, local_limit: 15),
      build(:queue, queue: "matching", paused: true, local_limit: 20)
    ]
  end

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
