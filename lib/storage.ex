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

        save_profile(name, profile)
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
