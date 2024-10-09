# ObanConsole

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `oban_console` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oban_console, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/oban_console>.

Menus:
1. Queues
2. Jobs
0. Exit

Queues:
  [0 to Return]

1. List
2. Pause
3. Resume

Queues - List: Lists all queues
  [0 to Return]

1. Pause
2. Resume

Queues - Pause:
  [0 to Return]

  Queue Name:

Queues - Resume:
  [0 to Return]

  Queue Name:

Jobs:
  [0 to Return]

1. List
2. Debug
3. Retry
4. Cancel

Jobs - List:
  [0 to Return]

  IDs (splited by ,):
  States (splited by ,):
  Queues (splited by ,):
  Fields (splited by ,):
  Limit (default 10):

  Table []

1. Refresh
2. Debug
3. Retry
4. Cancel

Jobs - Debug:
  [0 to Return]

  IDs (splited by ,):
  Fields (splited by ,):

1. Retry
2. Cancel

Jobs - Retry:
  [0 to Return]

  IDs (splited by ,):

1. Debug
2. Cancel

Jobs - Cancel:
  [0 to Return]

  IDs (splited by ,):

1. Debug
2. Retry
