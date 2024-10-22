defmodule BuildLiveFile do
  def sort_modules(files), do: sort_modules([], files, [])

  def sort_modules(sorted, [%{file: file, deps: []} = _module | remaining], depending) do
    sort_modules([file | sorted], remaining, depending)
  end

  def sort_modules(sorted, [%{file: file, deps: deps} = module | remaining], depending) do
    previous_sorted_deps =
      sorted
      |> Enum.with_index()
      |> Enum.filter(fn {f, _i} -> f in deps end)

    case previous_sorted_deps do
      [] = _any_dep_not_found ->
        sort_modules(sorted, remaining, [module | depending])

      _ ->
        last_dep_index =
          previous_sorted_deps
          |> Enum.map(&elem(&1, 1))
          |> List.last()

        first_slice = Enum.slice(sorted, 0, last_dep_index + 1)
        last_slice = Enum.slice(sorted, last_dep_index + 1, length(sorted))

        sorted = first_slice ++ [file] ++ last_slice

        sort_modules(sorted, remaining, depending)
    end
  end

  def sort_modules(sorted, [], [_ | _] = depending),
    do: sort_modules(sorted, depending, [])

  def sort_modules(sorted, [], []), do: sorted

  def read_files(sorted_files) do
    Enum.map(sorted_files, fn file -> File.read(file) end)
  end

  def write_files(files_content) do
    File.write("live.exs", Enum.join(files_content, "\n"))
  end
end

{:ok, spec_file} = File.read(".live.json")
spec_decoded = Jason.decode!(spec_file, keys: :atoms)

BuildLiveFile.sort_modules(spec_decoded)
