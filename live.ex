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

defmodule Oban.Console.Storage do
  def get_last_jobs_opts() do
    case System.get_env("OBAN_CONSOLE_JOBS_LAST_OPTS") do
      nil -> []
      value -> value |> Jason.decode!(keys: :atoms) |> Map.to_list()
    end
  end

  def set_last_jobs_opts(opts) do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", opts |> Map.new() |> Jason.encode!())
  end
end

defmodule Oban.Console.Queues do
  def list() do
    Enum.map(Oban.config().queues, fn {name, _} ->
      [queue: name]
      |> Oban.check_queue()
      |> Map.take([:queue, :paused, :local_limit])
    end)
  end

  def show_list() do
    headers = [:queue, :paused, :local_limit]

    Oban.Console.View.Table.show(list(), headers, nil)
  end

  def pause(name), do: Oban.pause_queue(queue: name)

  def resume(name), do: Oban.resume_queue(queue: name)
end

defmodule Oban.Console.Jobs do
  @in_progress_states ~w[available scheduled retryable executing]
  @failed_states ~w[cancelled discarded]

  import Ecto.Query

  alias Oban.Console.Storage

  def list(opts \\ []) do
    Oban
    |> Oban.config()
    |> Oban.Repo.all(list_query(opts))
  end

  def show_list(opts \\ []) do
    headers = [:id, :worker, :state, :queue, :attempt, :attempted_at, :scheduled_at]
    opts = if opts == [], do: Storage.get_last_jobs_opts(), else: opts

    Storage.set_last_jobs_opts(opts)

    response = list(opts)

    # Oban
    # |> Oban.config()
    # |> Oban.Repo.to_sql(:all, list_query(opts))
    # |> elem(0)
    # |> IO.puts()

    Oban.Console.View.Table.show(
      response,
      headers,
      "Filters: #{inspect(opts)} Sorts: DESC attempted_at, state"
    )
  end

  def clean_storage(), do: Storage.set_last_jobs_opts([])

  def retry(job_id) when is_integer(job_id), do: Oban.retry_job(job_id)
  def retry([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &Oban.retry_job/1)

  def cancel(job_id) when is_integer(job_id), do: Oban.cancel_job(job_id)
  def cancel([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &Oban.cancel_job/1)

  defp to_sql(query), do: Oban |> Oban.config() |> Oban.Repo.to_sql(query, :all)

  defp list_query(opts) do
    Oban.Job
    |> filter_by_ids(Keyword.get(opts, :ids))
    |> filter_by_states(Keyword.get(opts, :states))
    |> filter_by_queues(Keyword.get(opts, :queues))
    |> sort_by_attempted_at()
    |> sort_by_states()
    |> limit_by(Keyword.get(opts, :limit, 20))
  end

  defp filter_by_ids(query, nil), do: query
  defp filter_by_ids(query, []), do: query
  defp filter_by_ids(query, ids), do: where(query, [j], j.id in ^ids)

  defp filter_by_states(query, nil), do: query
  defp filter_by_states(query, []), do: query

  defp filter_by_states(query, states) do
    selected_states =
      states
      |> Enum.map(fn
        "in_progress" -> @in_progress_states
        "failed" -> @failed_states
        state -> state
      end)
      |> List.flatten()

    where(query, [j], j.state in ^selected_states)
  end

  defp filter_by_queues(query, nil), do: query
  defp filter_by_queues(query, []), do: query
  defp filter_by_queues(query, queues), do: where(query, [j], j.queue in ^queues)

  defp limit_by(query, limit), do: limit(query, ^limit)

  defp sort_by_attempted_at(query), do: order_by(query, [j], desc: j.attempted_at)

  defp sort_by_states(query) do
    order_by(
      query,
      [_],
      fragment("""
        CASE state WHEN 'executing' THEN 1 WHEN 'available' THEN 2 WHEN 'retryable' THEN 3WHEN 'scheduled' THEN 4WHEN 'completed' THEN 5WHEN 'discarded' THEN 6WHEN 'cancelled' THEN 7
        END
      """)
    )
  end
end

defmodule Oban.Console.View.Printer do
  @spec line(integer()) :: :ok
  def line(size \\ 80), do: separator(size) |> IO.puts()

  @spec separator(integer()) :: String.t()
  def separator(size \\ 80), do: String.pad_trailing("", size, "-")

  def menu(label, items) do
    IO.puts("")

    profile = System.get_env("OBAN_CONSOLE_PROFILE")

    if System.get_env("OBAN_CONSOLE_PROFILE") do
      IO.write("[#{header_color(profile)}] ")
    end

    IO.puts(header_color(label))

    Enum.each(items, fn {key, value} ->
      IO.puts("#{header_color(to_string(key) <> ".")} #{value}")
    end)
  end

  @spec break() :: :ok
  def break, do: IO.puts("")

  def gets([header | remaining]) do
    [header_color(header), remaining]
    |> List.flatten()
    |> Enum.join(" | ")
    |> IO.gets()
    |> String.trim()
  end

  def header_color(text), do: IO.ANSI.light_blue() <> text <> IO.ANSI.reset()

  def showable(value) when is_binary(value), do: value
  def showable(value), do: inspect(value)

  def red(text), do: IO.ANSI.red() <> text <> IO.ANSI.reset()
  def green(text), do: IO.ANSI.green() <> text <> IO.ANSI.reset()
  def light_yellow(text), do: IO.ANSI.light_yellow() <> text <> IO.ANSI.reset()
  def light_black(text), do: IO.ANSI.light_black() <> text <> IO.ANSI.reset()
  def light_magenta(text), do: IO.ANSI.light_magenta() <> text <> IO.ANSI.reset()
  def light_green(text), do: IO.ANSI.light_green() <> text <> IO.ANSI.reset()
  def light_red(text), do: IO.ANSI.light_red() <> text <> IO.ANSI.reset()
end

defmodule Oban.Console.View.Table do
  alias Oban.Console.View.Printer

  def show([], _, title) do
    Printer.break()

    if title, do: Printer.header_color(title) |> IO.puts()

    IO.puts("No records found")
  end

  def show([record | _] = records, headers, title) when not is_map(record) do
    records
    |> Enum.map(&Map.from_struct/1)
    |> show(headers, title)
  end

  def show([_ | _] = records, headers, title) do
    rows =
      records
      |> Enum.map(fn r ->
        Enum.map(headers, fn header -> Map.get(r, header) |> Printer.showable() end)
      end)

    headers = Enum.map(headers, &to_string/1)
    table = [headers | rows]

    indexes_pad = build_indexes_pad(table)

    line_size = Enum.sum(indexes_pad) + 1 + length(indexes_pad) * 3

    table_with_pads =
      [build_row_with_pad(headers, indexes_pad, :header)]
      |> append_list([Printer.separator(line_size)])
      |> append_list(Enum.map(rows, fn row -> build_row_with_pad(row, indexes_pad, :row) end))
      |> Enum.join("\n")

    Printer.break()

    if title, do: Printer.header_color(title) |> IO.puts()
    Printer.line(line_size)

    IO.puts(table_with_pads)
    Printer.line(line_size)
  end

  defp append_list(list, value), do: list ++ value

  defp build_row_with_pad(row, indexes_pad, type) do
    formatted =
      row
      |> Enum.with_index()
      |> Enum.map_join(" | ", fn {value, index} ->
        value
        |> String.pad_trailing(Enum.at(indexes_pad, index))
        |> colorize(type)
      end)

    "| " <> formatted <> " |"
  end

  defp colorize(value, type), do: color_for(value, String.trim(value), type)

  defp color_for(value, "false", :row), do: Printer.red(value)
  defp color_for(value, "true", :row), do: Printer.green(value)
  defp color_for(value, "executing", :row), do: Printer.light_yellow(value)
  defp color_for(value, "available", :row), do: Printer.light_black(value)
  defp color_for(value, "scheduled", :row), do: Printer.light_magenta(value)
  defp color_for(value, "completed", :row), do: Printer.light_green(value)
  defp color_for(value, "discarded", :row), do: Printer.light_red(value)
  defp color_for(value, "cancelled", :row), do: Printer.red(value)
  defp color_for(value, "retryable", :row), do: Printer.light_red(value)
  defp color_for(value, _, :header), do: Printer.header_color(value)
  defp color_for(value, _, _), do: value

  defp build_indexes_pad([headers | _] = table) do
    headers
    |> Enum.with_index()
    |> Enum.map(fn {_, index} ->
      Enum.reduce(table, 0, fn row, acc ->
        value = Enum.at(row, index)
        size = (value && String.length(value)) || 0

        max(acc, size)
      end)
    end)
  end
end

defmodule Oban.Console.Interactive do
  alias Oban.Console.Jobs
  alias Oban.Console.Queues
  alias Oban.Console.View.Printer

  def start() do
    initial_menu()
  end

  defp initial_menu() do
    Printer.menu("Menu:", [
      {1, "Queues"},
      {2, "Jobs"},
      {3, "Workers"},
      {4, "Profile"},
      {0, "Exit"}
    ])

    case Printer.gets(["Select an option: "]) do
      "1" -> queues()
      "2" -> jobs()
      "3" -> IO.puts("Comming soon") && initial_menu()
      "4" -> profile()
      "" -> initial_menu()
      "0" -> goodbye()
      _ -> goodbye()
    end
  end

  defp goodbye(), do: Printer.menu("Goodbye!", [])

  defp profile() do
    case Printer.gets(["Profile", "Select/Create your profile", "Name: "]) do
      "0" -> initial_menu()
      value -> System.put_env("OBAN_CONSOLE_PROFILE", value) && initial_menu()
    end
  end

  defp queues() do
    Queues.show_list()
    Printer.menu("Queues:", [{1, "List"}, {2, "Pause"}, {3, "Resume"}, {0, "Return"}])

    case Printer.gets(["Select an option: "]) do
      "1" -> queues()
      "2" -> pause_queue()
      "3" -> resume_queue()
      "0" -> initial_menu()
      "" -> queues()
      _ -> goodbye()
    end
  end

  defp resume_queue() do
    case Printer.gets(["Resume", "Queue name: "]) do
      "0" -> queues()
      queue -> Queues.resume(queue) && Queues.show_list() && queues()
    end
  end

  defp pause_queue() do
    case Printer.gets(["Pause", "Queue name: "]) do
      "0" -> queues()
      queue -> Queues.pause(queue) && Queues.show_list() && queues()
    end
  end

  defp jobs(opts \\ []) do
    Jobs.show_list(opts)

    Printer.menu("Jobs:", [
      {1, "Refresh"},
      {2, "Filter"},
      {3, "Debug"},
      {4, "Retry"},
      {5, "Cancel"},
      {6, "Clean"},
      {0, "Return"}
    ])

    case Printer.gets(["Select an option: "]) do
      "1" -> jobs()
      "2" -> filter_jobs()
      "3" -> IO.puts("Comming soon") && jobs()
      "4" -> IO.puts("Comming soon") && jobs()
      "5" -> IO.puts("Comming soon") && jobs()
      "6" -> clean_jobs() && jobs()
      "0" -> initial_menu()
      "" -> jobs()
      _ -> goodbye()
    end
  end

  defp clean_jobs(), do: Jobs.clean_storage()

  defp filter_jobs() do
    ids =
      Printer.gets(["Filter", "Job IDs (comma separated): "])
      |> String.split(",")
      |> Enum.map(fn s -> s |> String.trim() |> parse_to_integer() end)
      |> presence()

    states =
      Printer.gets([
        "Filter",
        "States (comma separated) (available, scheduled, retryable, executing, completed, discarded, cancelled): "
      ])
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> presence()

    jobs(ids: ids, states: states)
  end

  defp parse_to_integer(""), do: nil
  defp parse_to_integer(value), do: String.to_integer(value)

  defp presence(nil), do: nil
  defp presence([]), do: nil
  defp presence(""), do: nil
  defp presence([_ | _] = list), do: Enum.filter(list, &presence/1)
  defp presence(value), do: value
end

Oban.Console.Interactive.start()
