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
    list =
      with %{} = profiles <- Storage.get_profiles() do
        list =
          profiles
          |> Enum.map(fn {p, _} -> p != "selected" end)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort()
          |> Enum.with_index()
          |> Enum.map(fn {{k, _}, i} -> {i + 1, k} end)

        if Enum.any?(list), do: Printer.menu("Profiles", list)

        list
      else
        _ -> []
      end

    name = Printer.gets(["Select/Create your profile", "Number/Name: "])

    case Storage.find_or_create_profile(name, list) do
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
      {7, "History"},
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

  defp job_filters_history() do
    case Storage.get_profile() do
      {:ok, content} -> Enum.each(content.jobs.history, &IO.puts/1)
      _ -> nil
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
    do: job_filters_history() || jobs([], false)

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
