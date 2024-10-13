defmodule Oban.Console.View.Printer do
  @spec line(integer()) :: :ok
  def line(size \\ 80), do: separator(size) |> IO.puts()

  @spec separator(integer()) :: String.t()
  def separator(size \\ 80), do: String.pad_trailing("", size, "-")

  def menu(label, items) do
    IO.puts("")

    profile = System.get_env("OBAN_CONSOLE_PROFILE")

    if profile != nil && profile != "" do
      IO.write("[#{header_color(profile)}] ")
    end

    IO.puts(header_color(label))

    Enum.each(items, fn {key, value} ->
      IO.puts("#{header_color(to_string(key) <> ".")} #{value}")
    end)
  end

  @spec break() :: :ok
  def break, do: IO.puts("")

  def title([header | remaining]) do
    [header_color(header), remaining]
    |> List.flatten()
    |> Enum.join(" | ")
  end

  def gets(items, convert \\ nil) do
    data =
      title(items)
      |> IO.gets()
      |> String.trim()

    case convert do
      :downcase -> String.downcase(data)
      _ -> data
    end
  end

  def header_color(text), do: IO.ANSI.light_blue() <> text <> IO.ANSI.reset()

  def showable(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  def showable(%NaiveDateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
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

  def get_last_jobs_ids() do
    case System.get_env("OBAN_CONSOLE_JOBS_LAST_IDS") do
      nil -> []
      value -> value |> Jason.decode!()
    end
  end

  def set_last_jobs_ids(ids) do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", ids |> Jason.encode!())
  end

  def set_profile(name, file_path) do
    with {_, :ok} <- {:dir, file_path |> Path.dirname() |> File.mkdir_p()},
    {_, {:error, :enoent}} <- {:file, File.read(file_path)},

  else
    {:dir, {:error, reason}} ->
      {:error, "Failed to create the directory: #{reason}"}

    {:file, file} ->




  end
    case File.mkdir_p(path) do
      :ok ->
        IO.puts("Diretório criado com sucesso!")
      {:error, reason} ->
        IO.puts("Falha ao criar o diretório: #{reason}")
    end


    System.put_env("OBAN_CONSOLE_PROFILE", name)
    System.put_env("OBAN_CONSOLE_PROFILE_FILE_PATH", file_path)


  end
end

defmodule Oban.Console.Queues do
  alias Oban.Console.View.Printer
  alias Oban.Console.View.Table

  def list() do
    Enum.map(Oban.config().queues, fn {name, _} ->
      [queue: name]
      |> Oban.check_queue()
      |> Map.take([:queue, :paused, :local_limit])
    end)
  end

  def show_list() do
    headers = [:queue, :paused, :local_limit]

    Table.show(list(), headers, nil)
  end

  def pause_queues([_ | _] = names), do: Enum.each(names, &pause_queues/1)
  def pause_queues([]), do: :ok

  def pause_queues(name) do
    Oban.pause_queue(queue: name)
    ["Paused", name] |> Printer.title() |> IO.puts()
  end

  def pause_queues(name) do
    ["Pause", name, "Queue name is not valid"] |> Printer.title() |> IO.puts()
  end

  def resume_queues([_ | _] = names), do: Enum.each(names, &resume_queues/1)
  def resume_queues([]), do: :ok

  def resume_queues(name) do
    Oban.resume_queue(queue: name)
    ["Resumed", name] |> Printer.title() |> IO.puts()
  end

  def resume_queues(name) do
    ["Resume", name, "Queue name is not valid"] |> Printer.title() |> IO.puts()
  end
end

defmodule Oban.Console.Jobs do
  alias Oban.Console.View.Printer

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

  import Ecto.Query

  alias Oban.Console.Storage

  def list(opts \\ []) do
    Oban
    |> Oban.config()
    |> Oban.Repo.all(list_query(opts))
  end

  defp ids_listed_before(opts) do
    case Keyword.get(opts, :ids, []) do
      nil -> []
      [0] -> Storage.get_last_jobs_ids()
      ids -> ids
    end
  end

  def show_list(opts \\ []) do
    headers = [:id, :worker, :state, :queue, :attempt, :inserted_at, :attempted_at, :scheduled_at]
    opts = if opts == [], do: Storage.get_last_jobs_opts(), else: opts

    limit = Keyword.get(opts, :limit, 20) || 20
    converted_states = convert_states(Keyword.get(opts, :states, [])) || []
    ids = ids_listed_before(opts)

    opts = Keyword.put(opts, :ids, ids)
    opts = Keyword.put(opts, :states, converted_states)
    opts = Keyword.put(opts, :limit, limit)

    Storage.set_last_jobs_opts(opts)

    response = list(opts)

    ids = Enum.map(response, fn job -> job.id end)
    Storage.set_last_jobs_ids(ids)

    filters =
      Enum.reject(opts, fn
        {_, nil} -> true
        {_, []} -> true
        {_, _} -> false
      end)

    current_time = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")

    Oban.Console.View.Table.show(
      response,
      headers,
      "[#{current_time}] Rows: #{length(response)} Filters: #{inspect(filters)} Sorts: DESC attempted_at, DESC scheduled_at"
    )
  rescue
    e ->
      Printer.red(inspect(e)) |> IO.puts()
      Storage.set_last_jobs_opts([])

      show_list()
  end

  def clean_storage(), do: Storage.set_last_jobs_opts([])

  def debug_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &debug_jobs/1)
  def debug_jobs([]), do: :ok

  def debug_jobs(job_id) when is_integer(job_id) do
    Oban
    |> Oban.config()
    |> Oban.Repo.get(Oban.Job, job_id)
    |> then(fn
      nil ->
        ["Job", job_id, "Job not found"] |> Printer.title() |> IO.puts()

      job ->
        ["Job", job_id] |> Printer.title() |> IO.puts()
        IO.inspect(job)
    end)
  end

  def debug_jobs(job_id) do
    ["Debug", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def retry_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &retry_jobs/1)
  def retry_jobs([]), do: :ok

  def retry_jobs(job_id) when is_integer(job_id) do
    Oban.retry_job(job_id)
    ["Retried", job_id] |> Printer.title() |> IO.puts()
  end

  def retry_jobs(job_id) do
    ["Retry", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &cancel_jobs/1)
  def cancel_jobs([]), do: :ok

  def cancel_jobs(job_id) when is_integer(job_id) do
    Oban.cancel_job(job_id)
    ["Cancelled", job_id] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs(job_id) do
    ["Cancel", job_id, "Job ID is not valid"] |> Printer.title() |> IO.puts()
  end

  defp list_query(opts) do
    Oban.Job
    |> filter_by_ids(Keyword.get(opts, :ids))
    |> filter_by_states(Keyword.get(opts, :states))
    |> filter_by_queues(Keyword.get(opts, :queues))
    |> filter_by_workers(Keyword.get(opts, :workers))
    |> sort_by_attempted_at()
    |> sort_by_scheduled_at()
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

  defp sort_by_attempted_at(query) do
    query
    |> order_by(
      [j],
      fragment(
        "CASE WHEN attempted_at IS NULL THEN '2050-12-30 00:00:00.000' ELSE attempted_at END"
      )
    )
    |> order_by([j], desc: j.attempted_at)
  end

  defp sort_by_scheduled_at(query), do: order_by(query, [j], desc: j.scheduled_at)
end

defmodule Oban.Console.Interactive do
  alias Oban.Console.Jobs
  alias Oban.Console.Queues
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer

  def start() do
    initial_menu()
  end

  defp initial_menu() do
    Printer.menu("Menu:", [
      {1, "Jobs"},
      {2, "Queues"},
      {3, "Profile"},
      {0, "Exit"}
    ])

    ["Select an option: "]
    |> Printer.gets(:downcase)
    |> command(:initial_menu)
  end

  defp goodbye(), do: Printer.menu("Goodbye!", [])

  defp profile() do
    name = Printer.gets(["Profile", "Select/Create your profile", "Name: "])
    file_path = Printer.gets(["File Path", "Profile file path (default: ~/tmp/oban_console/profiles/#{name}): "])

    case Storage.set_profile(name, file_path) do
      :ok -> Printer.green("Profile set") |> IO.puts()
      {:error, error} -> Printer.red("Error | #{error}") |> IO.puts()
    end
  end

  defp queues() do
    Queues.show_list()

    Printer.menu(
      "Queues:",
      [
        {1, "List/Refresh"},
        {2, "Pause"},
        {3, "Resume"},
        {0, "Return"}
      ]
    )

    ["Select an option: "]
    |> Printer.gets(:downcase)
    |> command(:queues)
  end

  defp resume_queue() do
    ["Resume", "Queue name: "]
    |> get_customer_string_list_input()
    |> command(:resume_queues)
  end

  defp pause_queue() do
    ["Pause", "Queue name: "]
    |> get_customer_string_list_input()
    |> command(:pause_queues)
  end

  defp jobs(opts \\ [], list \\ true) do
    if list, do: Jobs.show_list(opts)

    Printer.menu("Jobs:", [
      {1, "List/Refresh"},
      {2, "Filter"},
      {3, "Debug"},
      {4, "Retry"},
      {5, "Cancel"},
      {6, "Clean"},
      {0, "Return"}
    ])

    ["Select an option: "]
    |> Printer.gets(:downcase)
    |> command(:jobs)
  end

  defp debug_jobs() do
    ["Debug", "Job IDs (comma separated): "]
    |> get_customer_integer_list_input()
    |> command(:debug_jobs)
  end

  defp clean_jobs(), do: Jobs.clean_storage()

  defp cancel_jobs() do
    ["Cancel", "Job IDs (comma separated): "]
    |> get_customer_integer_list_input()
    |> command(:cancel_jobs)
  end

  defp retry_jobs() do
    ["Retry", "Job IDs (comma separated): "]
    |> get_customer_integer_list_input()
    |> command(:retry_jobs)
  end

  defp command(value, :initial_menu) when value in ["1", "jobs"], do: jobs()
  defp command(value, :initial_menu) when value in ["2", "queues"], do: queues()
  defp command(value, :initial_menu) when value in ["3", "profile"], do: profile() && initial_menu()
  defp command(value, :initial_menu) when value in ["0", "exit"], do: goodbye()

  defp command(value, :queues) when value in ["1", "list", "refresh", "list/refresh", ""],
    do: queues()

  defp command(value, :queues) when value in ["2", "pause"], do: pause_queue() && queues()
  defp command(value, :queues) when value in ["3", "resume"], do: resume_queue() && queues()

  defp command(value, :resume_queues) when value in ["0", "return", "", []], do: queues()
  defp command(value, :resume_queues), do: Queues.resume_queues(value)

  defp command(value, :pause_queues) when value in ["0", "return", "", []], do: queues()
  defp command(value, :pause_queues), do: Queues.pause_queues(value)

  defp command(value, :jobs) when value in ["1", "list", "refresh", "list/refresh", ""],
    do: jobs()

  defp command(value, :jobs) when value in ["2", "filter"], do: filter_jobs()
  defp command(value, :jobs) when value in ["3", "debug"], do: debug_jobs() && jobs([], false)
  defp command(value, :jobs) when value in ["4", "retry"], do: retry_jobs() && jobs()
  defp command(value, :jobs) when value in ["5", "cancel"], do: cancel_jobs() && jobs()
  defp command(value, :jobs) when value in ["6", "clean"], do: clean_jobs() && jobs()

  defp command(value, :debug_jobs) when value in ["0", "return", "", []], do: jobs()
  defp command(value, :debug_jobs), do: Jobs.debug_jobs(value)

  defp command(value, :retry_jobs) when value in ["0", "return", "", []], do: jobs()
  defp command(value, :retry_jobs), do: Jobs.retry_jobs(value)

  defp command(value, :cancel_jobs) when value in ["0", "return", "", []], do: jobs()
  defp command(value, :cancel_jobs), do: Jobs.cancel_jobs(value)

  defp command(value, :filter_jobs_opts) do
    with true <- String.contains?(value, "["),
         {:ok, opts} <- eval_opts(value) do
      jobs(opts)
    else
      {:error, error} ->
        Printer.red("Error | Filter not valid") |> IO.puts()

        jobs()

      _ -> goodbye()
    end
  end

  defp command(value, _) when value in ["0", "return", ""], do: initial_menu()

  defp command(value, :jobs), do: command(value, :filter_jobs_opts)

  defp command(_, _), do: goodbye()

  def eval_opts(opts) do
    {keyword_list, _binding} = Code.eval_string(opts)

    {:ok, keyword_list}
  rescue
    _ -> {:error, "Not valid list"}
  end

  defp print_list(list), do: Enum.map_join(list, ", ", &to_string/1)

  defp filter_jobs() do
    previous_selected_opts = Storage.get_last_jobs_opts()
    previous_listed_ids = Storage.get_last_jobs_ids()
    previous_selected_ids = Keyword.get(previous_selected_opts, :ids, [])
    previous_selected_states = Keyword.get(previous_selected_opts, :states, [])
    previous_selected_queues = Keyword.get(previous_selected_opts, :queues, [])
    previous_selected_workers = Keyword.get(previous_selected_opts, :workers, [])

    Printer.break()

    if Enum.any?(previous_listed_ids),
      do: Printer.title(["Listed IDs", print_list(previous_listed_ids)]) |> IO.puts()

    if Enum.any?(previous_selected_ids),
      do: Printer.title(["Selected IDs", print_list(previous_listed_ids)]) |> IO.puts()

    Printer.title([
      "States",
      "1. available, 2. scheduled, 3. retryable, 4. executing, 5. completed, 6. discarded, 7. cancelled"
    ])
    |> IO.puts()

    if Enum.any?(previous_selected_states),
      do: Printer.title(["Selected States", print_list(previous_selected_states)]) |> IO.puts()

    Printer.title(["Queues", Queues.list() |> Enum.map(fn q -> q.queue end) |> print_list()])
    |> IO.puts()

    if Enum.any?(previous_selected_queues),
      do: Printer.title(["Selected Queues", print_list(previous_selected_queues)]) |> IO.puts()

    if Enum.any?(previous_selected_workers),
      do: Printer.title(["Selected Workers", print_list(previous_selected_workers)]) |> IO.puts()

    Printer.break()

    ids = get_customer_integer_list_input(["Filter", "IDs (comma separated): "])
    states = get_customer_string_list_input(["Filter", "States (comma separated): "])
    queues = get_customer_string_list_input(["Filter", "Queues (comma separated): "])

    workers =
      get_customer_string_list_input(["Filter", "Workers (comma separated, - to exclude): "])

    limit =
      ["Filter", "Limit (default 20): "] |> get_customer_integer_list_input() |> List.first()

    jobs(ids: ids, states: states, limit: limit, workers: workers, queues: queues)
  end

  defp get_customer_integer_list_input(title) do
    Printer.gets(title)
    |> String.split(",")
    |> Enum.map(fn s -> s |> String.trim() |> parse_to_integer() end)
    |> presence()
  end

  defp get_customer_string_list_input(title) do
    Printer.gets(title)
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> presence()
  end

  defp parse_to_integer(""), do: nil

  defp parse_to_integer(value) do
    String.to_integer(value)
  rescue
    ArgumentError -> nil
  end

  defp presence(nil), do: nil
  defp presence([]), do: nil
  defp presence(""), do: nil
  defp presence([_ | _] = list), do: Enum.filter(list, &presence/1)
  defp presence(value), do: value
end

Oban.Console.Interactive.start()
