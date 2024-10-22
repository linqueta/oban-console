defmodule Oban.Console do
  def interactive() do
    case Oban.Console.Config.oban_configured?() do
      {:error, reason} ->
        ["Error", reason] |> Printer.error() |> IO.puts()

        {:error, reason}

      :ok ->
        Oban.Console.Interactive.start()
    end
  end
end
