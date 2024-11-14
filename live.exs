defmodule Oban.Console.Storage do
  @spec get_last_jobs_opts() :: list
  def get_last_jobs_opts do
    case get_env("OBAN_CONSOLE_JOBS_LAST_OPTS") do
      nil -> []
      "" -> []
      value -> value |> Jason.decode!(keys: :atoms) |> Map.to_list()
    end
  end

  @spec set_last_jobs_opts(list) :: :ok
  def set_last_jobs_opts(opts) do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", opts |> Map.new() |> Jason.encode!())
  end

  @spec get_last_jobs_ids() :: list
  def get_last_jobs_ids do
    case get_env("OBAN_CONSOLE_JOBS_LAST_IDS") do
      nil -> []
      "" -> []
      value -> value |> Jason.decode!()
    end
  end

  @spec set_last_jobs_ids(list) :: :ok
  def set_last_jobs_ids(ids) do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", ids |> Jason.encode!())
  end

  @spec find_or_create_profile(String.t(), []) :: :ok
  def find_or_create_profile(nil, _), do: nil
  def find_or_create_profile("", _), do: nil

  def find_or_create_profile(name, list) when is_binary(name) do
    with nil <- Enum.find(list, fn {i, p} -> name in [i, p] end),
         {:ok, _content} <- save_profile(name, %{"filters" => []}) do
      put_oban_console_profile_env(name)
    else
      {_, selected_profile} ->
        profile = Map.get(get_profiles(), selected_profile)

        save_profile(selected_profile, profile)
        put_oban_console_profile_env(selected_profile)

      error ->
        error
    end
  end

  @spec delete_profile_file() :: :ok
  def delete_profile_file do
    %{file_path: file_path} = profile_file_path()

    put_oban_console_profile_env("")

    File.rm(file_path)
  end

  @spec get_profiles() :: map
  def get_profiles do
    %{file_path: file_path} = profile_file_path()

    case File.read(file_path) do
      {:ok, content} -> Jason.decode!(content)
      {:error, :enoent} -> nil
    end
  end

  @spec get_profile() :: {String.t(), map} | nil
  def get_profile do
    case get_profiles() do
      %{"selected" => selected} = profiles ->
        put_oban_console_profile_env(selected)

        {selected, Map.get(profiles, selected)}

      nil ->
        nil
    end
  end

  @spec get_profile_name() :: String.t() | nil
  def get_profile_name do
    with nil <- get_oban_console_profile_env(),
         {selected, _} <- get_profile() do
      selected
    else
      nil -> nil
      "" -> nil
      selected -> selected
    end
  end

  @spec add_job_filter_history(Keyword.t()) :: :ok
  def add_job_filter_history([_ | _] = filters), do: add_job_filter_history(Map.new(filters))

  def add_job_filter_history(filters) do
    case get_profile() do
      {selected, content} ->
        data = %{"filters" => [filters | Map.get(content, "filters")]}

        save_profile(selected, data)

        :ok

      _ ->
        :ok
    end
  end

  defp profile_file_path do
    path = "tmp/oban_console"
    file_name = "profiles.json"
    file_path = Path.join([path, file_name])

    %{path: path, file_name: file_name, file_path: file_path}
  end

  defp save_profile(name, content) do
    %{path: path, file_path: file_path} = profile_file_path()

    case get_profiles() do
      %{} = profiles ->
        change = %{"selected" => name, name => content}
        content = Map.merge(profiles, change)

        write_profile(file_path, content)

        {:ok, content}

      false ->
        {:ok, Map.get(get_profiles(), name)}

      nil ->
        File.mkdir_p(path)
        write_profile(file_path, %{})

        save_profile(name, content)

      error ->
        {:error, error}
    end
  end

  defp write_profile(file_path, content), do: File.write(file_path, Jason.encode!(content))

  defp get_oban_console_profile_env, do: get_env("OBAN_CONSOLE_PROFILE")
  defp put_oban_console_profile_env(value), do: System.put_env("OBAN_CONSOLE_PROFILE", value)

  defp get_env(name) do
    case System.get_env(name) do
      nil -> nil
      "" -> nil
      value -> value
    end
  end
end

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

  @spec pause_queue(atom()) :: :ok
  def pause_queue(name), do: Oban.pause_queue(queue: name)

  @spec resume_queue(atom()) :: :ok
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

defmodule Oban.Console.Config do
  @spec oban_configured?() :: :ok | {:error, String.t()}
  def oban_configured? do
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

defmodule Oban.Console.View.Printer do
  alias Oban.Console.Storage

  @spec line(integer()) :: :ok
  def line(size \\ 80), do: separator(size) |> IO.puts()

  @spec separator(integer()) :: String.t()
  def separator(size \\ 80), do: String.pad_trailing("", size, "-")

  @spec menu(String.t(), list()) :: :ok
  def menu(label, items) do
    break()

    profile = Storage.get_profile_name()

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

  @spec error([String.t()]) :: String.t()
  def error([header | remaining]) do
    [red(header), remaining]
    |> List.flatten()
    |> Enum.join(" | ")
  end

  @spec title([String.t()]) :: String.t()
  def title([header | remaining]) do
    [header_color(header), remaining]
    |> List.flatten()
    |> Enum.join(" | ")
  end

  @spec gets([String.t()], atom()) :: String.t()
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

  @spec header_color(String.t()) :: String.t()
  def header_color(text), do: IO.ANSI.light_blue() <> text <> IO.ANSI.reset()

  @spec showable(any()) :: String.t()
  def showable(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  def showable(%NaiveDateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  def showable(value) when is_binary(value), do: value
  def showable({value, _}), do: showable(value)
  def showable(value), do: inspect(value)

  @spec red(String.t()) :: String.t()
  def red(text), do: IO.ANSI.red() <> text <> IO.ANSI.reset()

  @spec green(String.t()) :: String.t()
  def green(text), do: IO.ANSI.green() <> text <> IO.ANSI.reset()

  @spec light_yellow(String.t()) :: String.t()
  def light_yellow(text), do: IO.ANSI.light_yellow() <> text <> IO.ANSI.reset()

  @spec light_black(String.t()) :: String.t()
  def light_black(text), do: IO.ANSI.light_black() <> text <> IO.ANSI.reset()

  @spec light_magenta(String.t()) :: String.t()
  def light_magenta(text), do: IO.ANSI.light_magenta() <> text <> IO.ANSI.reset()

  @spec light_green(String.t()) :: String.t()
  def light_green(text), do: IO.ANSI.light_green() <> text <> IO.ANSI.reset()

  @spec light_red(String.t()) :: String.t()
  def light_red(text), do: IO.ANSI.light_red() <> text <> IO.ANSI.reset()
end

defmodule Oban.Console.View.Table do
  alias Oban.Console.View.Printer

  @spec show([map()], [atom()], String.t()) :: :ok
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
        # Enum.map(headers, fn header -> Map.get(r, header) |> Printer.showable() end)
        Enum.map(headers, fn header -> Map.get(r, header) end)
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
        [value, old] =
          case value do
            {value, false} -> [value, false]
            {value, true} -> [value, true]
            _ -> [value, true]
          end

        value
        |> Printer.showable()
        |> String.pad_trailing(Enum.at(indexes_pad, index))
        |> colorize(type, old)
      end)

    "| " <> formatted <> " |"
  end

  defp colorize(value, type, false), do: color_for(value, "executing", type)
  defp colorize(value, type, true), do: color_for(value, String.trim(value), type)

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
        size = (value && String.length(Printer.showable(value))) || 0

        max(acc, size)
      end)
    end)
  end
end

defmodule Oban.Console.Jobs do
  import Ecto.Query

  alias Oban.Console.Repo
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer
  alias Oban.Console.View.Table

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

  @spec list([Keyword.t()]) :: [Oban.Job.t()]
  def list(opts \\ []), do: Repo.all(list_query(opts))

  @spec show_list([Keyword.t()]) :: :ok
  def show_list(opts \\ []) do
    headers = [:id, :worker, :state, :queue, :attempt, :inserted_at, :attempted_at, :scheduled_at, :completed_at]
    opts = if opts == [], do: Storage.get_last_jobs_opts(), else: opts

    limit = Keyword.get(opts, :limit, 20) || 20
    converted_states = convert_states(Keyword.get(opts, :states, [])) || []
    ids = ids_listed_before(opts)
    sorts = Keyword.get(opts, :sorts, ["desc:id"]) || ["desc:id"]

    opts =
      opts
      |> Keyword.put(:ids, ids)
      |> Keyword.put(:sorts, sorts)
      |> Keyword.put(:states, converted_states)
      |> Keyword.put(:limit, limit)

    response =
      opts
      |> list()
      |> Enum.map(&Map.from_struct/1)

    ids = Enum.map(response, fn job -> job.id end)

    listed_before = Storage.get_last_jobs_ids()

    response =
      Enum.map(response, fn job ->
        Map.put(job, :id, {job.id, job.id in listed_before})
      end)

    if Enum.sort(Storage.get_last_jobs_opts()) != Enum.sort(opts) do
      Storage.add_job_filter_history(opts)
    end

    Storage.set_last_jobs_ids(ids)
    Storage.set_last_jobs_opts(opts)

    filters =
      Enum.reject(opts, fn
        {_, nil} -> true
        {_, []} -> true
        {_, _} -> false
      end)

    current_time = Calendar.strftime(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S")

    Table.show(
      response,
      headers,
      "[#{current_time}] Rows: #{length(response)} Filters: #{inspect(filters)}"
    )
  rescue
    e ->
      Printer.red(inspect(e)) |> IO.puts()
      Storage.set_last_jobs_opts([])

      show_list()
  end

  @spec clean_storage() :: :ok
  def clean_storage, do: Storage.set_last_jobs_opts([])

  @spec debug_jobs([integer() | [integer()]]) :: :ok
  def debug_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &debug_jobs/1)
  def debug_jobs([]), do: :ok

  def debug_jobs(job_id) when is_integer(job_id) do
    case Repo.get_job(job_id) do
      nil ->
        ["Job", job_id, "Job not found"] |> Printer.error() |> IO.puts()

      job ->
        Printer.break()
        ["Job", job_id] |> Printer.title() |> IO.puts()

        # credo:disable-for-next-line
        IO.inspect(job)

        :ok
    end
  end

  def debug_jobs(job_id) do
    ["Debug", job_id, "Job ID is not valid"] |> Printer.error() |> IO.puts()
  end

  @spec retry_jobs([integer() | [integer()]]) :: :ok
  def retry_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &retry_jobs/1)
  def retry_jobs([]), do: :ok

  def retry_jobs(job_id) when is_integer(job_id) do
    Repo.retry_job(job_id)
    ["Retried", job_id] |> Printer.title() |> IO.puts()
  end

  def retry_jobs(job_id) do
    ["Retry", job_id, "Job ID is not valid"] |> Printer.error() |> IO.puts()
  end

  @spec cancel_jobs([integer() | [integer()]]) :: :ok
  def cancel_jobs([_ | _] = jobs_ids), do: Enum.each(jobs_ids, &cancel_jobs/1)
  def cancel_jobs([]), do: :ok

  def cancel_jobs(job_id) when is_integer(job_id) do
    Repo.cancel_job(job_id)
    ["Cancelled", job_id] |> Printer.title() |> IO.puts()
  end

  def cancel_jobs(job_id) do
    ["Cancel", job_id, "Job ID is not valid"] |> Printer.error() |> IO.puts()
  end

  defp ids_listed_before(opts) do
    case Keyword.get(opts, :ids, []) do
      nil -> []
      [0] -> Storage.get_last_jobs_ids()
      ids -> ids
    end
  end

  defp list_query(opts) do
    Oban.Job
    |> filter_by_ids(Keyword.get(opts, :ids))
    |> filter_by_states(Keyword.get(opts, :states))
    |> filter_by_queues(Keyword.get(opts, :queues))
    |> filter_by_workers(Keyword.get(opts, :workers))
    |> filter_by_args(Keyword.get(opts, :args))
    |> filter_by_meta(Keyword.get(opts, :meta))
    |> sort_by(Keyword.get(opts, :sorts))
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

  defp filter_by_args(query, nil), do: query

  defp filter_by_args(query, args) do
    where(query, [j], fragment("?::text", j.args) |> like(^"%#{args}%"))
  end

  defp filter_by_meta(query, nil), do: query

  defp filter_by_meta(query, meta) do
    where(query, [j], fragment("?::text", j.meta) |> like(^"%#{meta}%"))
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

  defp sort_by(query, nil), do: query
  defp sort_by(query, []), do: query

  defp sort_by(query, sorts) do
    Enum.reduce(sorts, query, fn sort, query -> sort_by_single(query, sort) end)
  end

  defp sort_by_single(query, sort) do
    [dir, selected_field] = String.split(sort, ":")
    parsed_field = String.to_atom(selected_field)

    case dir do
      "asc" -> order_by(query, [j], asc: field(j, ^parsed_field))
      "desc" -> order_by(query, [j], desc: field(j, ^parsed_field))
    end
  end
end

defmodule Oban.Console.Queues do
  alias Oban.Console.Repo
  alias Oban.Console.View.Printer
  alias Oban.Console.View.Table

  @spec list() :: [Oban.Queue.t()]
  def list, do: Repo.queues()

  @spec show_list() :: :ok
  def show_list do
    headers = [
      :queue,
      :paused,
      :local_limit,
      :available,
      :executing,
      :scheduled,
      :retryable,
      :completed,
      :cancelled,
      :discarded
    ]

    queues = list()
    queue_jobs = Repo.queue_jobs()

    default = %{
      queue: nil,
      paused: false,
      local_limit: nil,
      available: 0,
      executing: 0,
      scheduled: 0,
      retryable: 0,
      completed: 0,
      cancelled: 0,
      discarded: 0
    }

    queues =
      Enum.map(queues, fn queue ->
        states =
          queue_jobs
          |> Enum.filter(fn {name, _, _} -> name == queue.queue end)
          |> Enum.map(fn {_, state, count} -> {String.to_atom(state), count} end)
          |> Map.new()

        default |> Map.merge(queue) |> Map.merge(states)
      end)

    Table.show(queues, headers, nil)
  end

  @spec pause_queues([String.t()]) :: :ok
  def pause_queues([_ | _] = names), do: Enum.each(names, &pause_queues/1)
  def pause_queues([]), do: :ok

  def pause_queues(name) when is_binary(name) do
    Repo.pause_queue(String.to_atom(name))
    ["Paused", name] |> Printer.title() |> IO.puts()
  end

  def pause_queues(name) do
    ["Pause", name, "Queue name is not valid"] |> Printer.error() |> IO.puts()
  end

  @spec resume_queues([String.t()]) :: :ok
  def resume_queues([_ | _] = names), do: Enum.each(names, &resume_queues/1)
  def resume_queues([]), do: :ok

  def resume_queues(name) when is_binary(name) do
    Repo.resume_queue(String.to_atom(name))
    ["Resumed", name] |> Printer.title() |> IO.puts()
  end

  def resume_queues(name) do
    ["Resume", name, "Queue name is not valid"] |> Printer.error() |> IO.puts()
  end
end

defmodule Oban.Console.Interactive do
  alias Oban.Console.Jobs
  alias Oban.Console.Queues
  alias Oban.Console.Storage
  alias Oban.Console.View.Printer

  @spec start() :: :ok
  def start do
    initial_menu()
  end

  @spec initial_menu() :: :ok
  defp initial_menu do
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

  @spec goodbye() :: :ok
  defp goodbye, do: Printer.menu("Goodbye!", [])

  @spec profile() :: :ok
  defp profile do
    list =
      case Storage.get_profiles() do
        %{} = profiles ->
          options =
            profiles
            |> Enum.filter(fn {p, _} -> p != "selected" end)
            |> Enum.with_index()
            |> Enum.map(fn {{k, _}, i} -> {to_string(i + 1), k} end)

          Printer.menu("Profiles", options)

          options

        nil ->
          []
      end

    name = Printer.gets(["Select/Create your profile", "Number/Name: "])

    case Storage.find_or_create_profile(name, list) do
      :ok -> Printer.green("Profile set") |> IO.puts()
      {:error, error} -> Printer.red("Error | #{error}") |> IO.puts()
    end
  end

  @spec queues() :: :ok
  defp queues do
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

  @spec resume_queue() :: :ok
  defp resume_queue do
    ["Resume", "Queue name: "]
    |> get_customer_string_list_input()
    |> command(:resume_queues)
  end

  @spec pause_queue() :: :ok
  defp pause_queue do
    ["Pause", "Queue name: "]
    |> get_customer_string_list_input()
    |> command(:pause_queues)
  end

  @spec jobs(Keyword.t(), boolean()) :: :ok
  defp jobs(opts \\ [], list \\ true) do
    if list, do: Jobs.show_list(opts)

    Printer.menu("Jobs:", [
      {1, "List/Refresh"},
      {2, "Filter"},
      {3, "Debug"},
      {4, "Retry"},
      {5, "Cancel"},
      {6, "Clean"},
      {7, "History"},
      {0, "Return"}
    ])

    ["Select an option: "]
    |> Printer.gets(:downcase)
    |> command(:jobs)
  end

  @spec debug_jobs() :: :ok
  defp debug_jobs do
    ["Debug", "Job IDs (comma separated): "]
    |> get_customer_integer_list_input()
    |> command(:debug_jobs)
  end

  @spec clean_jobs :: :ok
  defp clean_jobs, do: Jobs.clean_storage()

  @spec cancel_jobs() :: :ok
  defp cancel_jobs do
    ["Cancel", "Job IDs (comma separated): "]
    |> get_customer_integer_list_input()
    |> command(:cancel_jobs)
  end

  @spec retry_jobs() :: :ok
  defp retry_jobs do
    ["Retry", "Job IDs (comma separated): "]
    |> get_customer_integer_list_input()
    |> command(:retry_jobs)
  end

  defp parse_filter_history(filter) do
    filter
    |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
    |> Map.to_list()
    |> inspect()
  end

  defp job_filters_history do
    case Storage.get_profile() do
      {_, %{"filters" => filters}} ->
        filters
        |> Enum.with_index()
        |> Enum.map(fn {filter, i} -> {i, parse_filter_history(filter)} end)
        |> then(fn list -> Printer.menu("Filters History", list) end)

        :ok

      _ ->
        Printer.red("Error | Profile not found | Add a Profile at the initial menu") |> IO.puts()

        :ok
    end
  end

  defp command(value, :initial_menu) when value in ["1", "jobs"], do: jobs()
  defp command(value, :initial_menu) when value in ["2", "queues"], do: queues()

  defp command(value, :initial_menu) when value in ["3", "profile"],
    do: profile() && initial_menu()

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

  defp command(value, :jobs) when value in ["7", "history"],
    do: job_filters_history() && jobs([], false)

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
      {:error, _error} ->
        Printer.red("Error | Filter not valid") |> IO.puts()

        jobs()

      _ ->
        goodbye()
    end
  end

  defp command(value, _) when value in ["0", "return", ""], do: initial_menu()

  defp command(value, :jobs), do: command(value, :filter_jobs_opts)

  defp command(_, _), do: goodbye()

  defp eval_opts(opts) do
    {keyword_list, _binding} = Code.eval_string(opts)

    {:ok, keyword_list}
  rescue
    _ -> {:error, "Not valid list"}
  end

  defp print_list(list), do: Enum.map_join(list, ", ", &to_string/1)

  defp filter_jobs do
    previous_selected_opts = Storage.get_last_jobs_opts()
    previous_listed_ids = Storage.get_last_jobs_ids()
    previous_selected_ids = Keyword.get(previous_selected_opts, :ids, [])
    previous_selected_states = Keyword.get(previous_selected_opts, :states, [])
    previous_selected_queues = Keyword.get(previous_selected_opts, :queues, [])
    previous_selected_workers = Keyword.get(previous_selected_opts, :workers, [])
    previous_selected_sorts = Keyword.get(previous_selected_opts, :sorts, [])
    previous_selected_args = Keyword.get(previous_selected_opts, :args, nil)
    previous_selected_meta = Keyword.get(previous_selected_opts, :meta, nil)

    Printer.break()

    print_selected("Listed IDs", previous_listed_ids)

    print_selected("Available States", [
      "1. available, 2. scheduled, 3. retryable, 4. executing, 5. completed, 6. discarded, 7. cancelled"
    ])

    Printer.break()

    print_selected("Selected IDs", previous_selected_ids)
    print_selected("Selected States", previous_selected_states)
    print_selected("Selected Queues", previous_selected_queues)
    print_selected("Selected Workers", previous_selected_workers)
    print_selected("Contains Args", [previous_selected_args])
    print_selected("Contains Meta", [previous_selected_meta])
    print_selected("Selected Sort", previous_selected_sorts)

    Printer.break()

    print_selected("Hint", ["Use comma to separate values", "Use - to clean filters", "Use : to sort values"])

    ids =
      ["Filter", "IDs: "]
      |> get_customer_integer_list_input()
      |> fallback(previous_selected_ids)

    states =
      ["Filter", "States: "]
      |> get_customer_string_list_input()
      |> fallback(previous_selected_states)

    queues =
      ["Filter", "Queues: "]
      |> get_customer_string_list_input()
      |> fallback(previous_selected_queues)

    workers =
      ["Filter", "Workers: "]
      |> get_customer_string_list_input()
      |> fallback(previous_selected_workers)

    args =
      ["Filter", "Args: "]
      |> get_customer_string_list_input()
      |> List.first()
      |> fallback(previous_selected_args)

    meta =
      ["Filter", "Meta: "]
      |> get_customer_string_list_input()
      |> List.first()
      |> fallback(previous_selected_meta)

    sorts =
      ["Filter", "Sorts: "]
      |> get_customer_string_list_input()
      |> Enum.map(fn s ->
        splited = if String.contains?(s, ":"), do: String.split(s, ":"), else: String.split(s, " ")
        trimmed = Enum.map(splited, &String.trim/1)

        case trimmed do
          [field] -> "asc:#{field}"
          [field, "asc"] -> "asc:#{field}"
          ["asc", field] -> "asc:#{field}"
          [field, "desc"] -> "desc:#{field}"
          ["desc", field] -> "desc:#{field}"
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> fallback(previous_selected_sorts)

    limit =
      ["Filter", "Limit (default 20): "] |> get_customer_integer_list_input() |> List.first() |> fallback(20)

    jobs(
      ids: ids,
      states: states,
      limit: limit,
      workers: workers,
      queues: queues,
      sorts: sorts,
      args: args,
      meta: meta
    )
  end

  defp print_selected(_, []), do: :ok
  defp print_selected(_, [nil]), do: :ok
  defp print_selected(text, list), do: Printer.title([text, print_list(list)]) |> IO.puts()

  defp fallback(nil, default), do: default
  defp fallback("-", _), do: []
  defp fallback([], default), do: default
  defp fallback(["-"], _), do: []
  defp fallback(value, _), do: value

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

Oban.Console.interactive()
