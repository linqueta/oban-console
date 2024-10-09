defmodule Oban.Console.Queues do
  alias Oban.Console.Config

  alias Oban.Console.Model.Queue

  def list_queues() do
    case Config.oban_configured?() do
      :ok ->
        %Oban.Config{queues: queues} = Oban.config()


      Enum.map(queues, fn [name, opts] ->
        limit = Keyword.get(opts, :limit)

        %Queue{name: queue.name, limit: queue.limit}
      end)


      error ->
        error
    end
  end
end
