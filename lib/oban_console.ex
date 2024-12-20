defmodule Oban.Console do
  alias Oban.Console.View.Printer

  @spec interactive() :: :ok | {:error, String.t()}
  def interactive do
    case Oban.Console.Config.oban_configured?() do
      {:error, reason} ->
        ["Error", reason] |> Printer.error() |> IO.puts()

        {:error, reason}

      :ok ->
        Oban.Console.Interactive.start()
    end
  end
end
