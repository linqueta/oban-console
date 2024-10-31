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

    ids =
      ["Filter", "IDs (comma separated): "]
      |> get_customer_integer_list_input()
      |> fallback(previous_selected_ids)

    states =
      ["Filter", "States (comma separated): "]
      |> get_customer_string_list_input()
      |> fallback(previous_selected_states)

    queues =
      ["Filter", "Queues (comma separated): "]
      |> get_customer_string_list_input()
      |> fallback(previous_selected_queues)

    workers =
      ["Filter", "Workers (comma separated, - to exclude): "]
      |> get_customer_string_list_input()
      |> fallback(previous_selected_workers)

    args =
      ["Filter", "Args (Contains): "]
      |> get_customer_string_list_input()
      |> List.first()
      |> fallback(previous_selected_args)

    meta =
      ["Filter", "Meta (Contains): "]
      |> get_customer_string_list_input()
      |> List.first()
      |> fallback(previous_selected_meta)

    sorts =
      ["Filter", "Sorts (comma separated): "]
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
  defp fallback([], default), do: default
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
