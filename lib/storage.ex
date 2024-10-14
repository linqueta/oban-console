defmodule Oban.Console.Storage do
  def get_last_jobs_opts() do
    case get_env("OBAN_CONSOLE_JOBS_LAST_OPTS") do
      nil -> []
      value -> value |> Jason.decode!(keys: :atoms) |> Map.to_list()
    end
  end

  def set_last_jobs_opts(opts) do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", opts |> Map.new() |> Jason.encode!())
  end

  def get_last_jobs_ids() do
    case get_env("OBAN_CONSOLE_JOBS_LAST_IDS") do
      nil -> []
      value -> value |> Jason.decode!()
    end
  end

  def set_last_jobs_ids(ids) do
    System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", ids |> Jason.encode!())
  end

  defp profile_file_path() do
    path = "tmp/oban_console"
    file_name = "profiles.json"
    file_path = Path.join([path, file_name])

    %{path: path, file_name: file_name, file_path: file_path}
  end

  def find_or_create_profile(nil, _), do: nil
  def find_or_create_profile("", _), do: nil

  def find_or_create_profile(name, list) when is_binary(name) do
    with nil <- Enum.find(list, fn {i, p} -> name in [i, p] end),
         {:ok, _content} <- save_profile(name, %{"filters" => []}, false) do
      put_oban_console_profile_env(name)
    else
      {_, selected_profile} ->
        put_oban_console_profile_env(selected_profile)

      error ->
        error
    end
  end

  def get_profiles() do
    %{file_path: file_path} = profile_file_path()

    case File.read(file_path) do
      {:ok, content} -> Jason.decode!(content)
      {:error, :enoent} -> nil
    end
  end

  def get_profile() do
    with %{} = content <- get_profiles(),
         %{"selected" => selected} = profiles <- Jason.decode!(content) do
      put_oban_console_profile_env(selected)

      {selected, Map.get(profiles, selected)}
    else
      nil -> nil
    end
  end

  def get_profile_name() do
    with nil <- get_oban_console_profile_env(),
         {selected, _} <- get_profile() do
      selected
    else
      nil -> nil
      selected -> selected
    end
  end

  def add_job_filter_history(filters) do
    with {selected, content} <- get_profile() do
      data = %{"filters" => [filters | Map.get(content, "filters")]}

      save_profile(selected, data)
    end
  end

  defp save_profile(name, content, update \\ true) do
    %{path: path, file_path: file_path} = profile_file_path()

    with %{} = profiles <- get_profiles(),
         true <- update || is_nil(Map.get(profiles, name)) do
      content = Map.merge(profiles, %{"selected" => name, name => content})

      write_profile(file_path, content)

      {:ok, content}
    else
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

  defp get_oban_console_profile_env(), do: get_env("OBAN_CONSOLE_PROFILE")
  defp put_oban_console_profile_env(value), do: System.put_env("OBAN_CONSOLE_PROFILE", value)

  defp get_env(name) do
    case System.get_env(name) do
      nil -> nil
      "" -> nil
      value -> value
    end
  end
end
