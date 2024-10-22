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
