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
