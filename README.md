# Oban.Console

[![Version](https://img.shields.io/hexpm/v/oban-console.svg)](https://hex.pm/packages/oban-console)
[![Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/oban-console/)

Query, debug, retry, cancel Oban jobs and much more easily.

![oban-console-800](https://github.com/user-attachments/assets/07a18917-e5dc-40ab-9dc7-2b102fc22616)

## Installation

```elixir
def deps do
  [
    {:oban_console, "~> 0.1.0"}
  ]
end
```

You can play before using in project setting the repo [Oban.Console.Playground](https://github.com/linqueta/oban-console-playground)

```shell
git clone https://github.com/linqueta/oban-console-playground.git
cd oban-console-playground

mix ecto.setup
iex -S mix phx.server

iex(1)> Oban.Console.interactive()
```

## Usage

Oban.Console can be used when instelled to your project or directly if you copy the file `live.exs` and paste at your console.

To start it, at your console, type `Oban.Console.interactive` and the main menu will open showing the follow options:

```
1. Jobs -> Explore the jobs
2. Queues -> Explore the queues
3. Profile -> Set or change the profile
0. Exit -> Exit the app. You can type any char in the menus and if it is not known it'll exit the app.
```

### Profiles
Save query history to your profile into share consoles

```
Profiles
1. Lincoln
2. Marianna
Select/Create your profile | Number/Name:
```

You can select or create a new one. Select by the number or name or creating a new for a different purpose.
Profiles saves the last job's queries performed, allowing to easy navigate into the job's queries history
In the future it could store more information.
It's save locally into the application container/pod/machine, so, once it could be empty if you refresh the state of the application

Once it's selected, it's showed at all menus:

```
[Lincoln] Menu:
1. Jobs
2. Queues
3. Profile
0. Exit
```

### Jobs
Explore easily the Oban Jobs

```
[Lincoln] Jobs:
1. List/Refresh
2. Filter
3. Debug
4. Retry
5. Cancel
6. Clean
7. History
0. Return
```

Always you started, the app tries to fetch the last query performed by your profile. In case that it's empty, it performs a query ordering by `desc:id`

![Jobs](https://github.com/user-attachments/assets/e390cfd1-ec79-45bf-9a3f-2ad5bf74768d)

The yellow color at ID column means new jobs that were not showed in the previous pagination. It helps to understand about the new jobs created while you didn't refresh the list.

#### Filter

![Filters](https://github.com/user-attachments/assets/ffa35271-4a46-4c78-ab3e-e8bf9fd72aa7)

```
Filter | IDs:
Filter | States:
Filter | Queues:
Filter | Workers: -> PlaceOrder,PayOrder or -CreateCustomer, -PlaceOrder
Filter | Args: -> Any word into the args - Example: 102030 <- The id of the customer
Filter | Meta: -> The same as args
Filter | Sorts: -> Example: inserted_at:desc, attempted_at:asc
Filter | Limit (default 20):
```

Once you filter by something, this filter will be applied when you leave the field empty in the next filter.
To clean a filter for a field you need to type `-` into the field or select the option `6` at the job's menu.

#### Debug

When you select `Debug` you can print the `Oban.Job` at the console, allowing checking all information inside it. It accepts many jobs at time splited by `,`

#### Retry

When you select `Retry` you can retry many jobs at once. Accepts more when splited by `,`.

#### Cancel

When you select `Cancel` you can cancel many jobs at once. Accepts more when splited by `,`.

#### Clean

The option `Clean` cleans all filters applied listing it sorted only by the job ID.

#### History

![History](https://github.com/user-attachments/assets/9178012b-df83-4cd0-ae76-0f2be43f890b)

The option `History` allows you to check the queries' history saved at the selected Profile. You can easily define filter by the queries listed copying and pasting their content into the command, like:

```
Select an option: [states: ["available"], limit: 50, ids: [], sorts: ["desc:id"]]
```

### Queues

![Queues](https://github.com/user-attachments/assets/ef8d288f-c09b-4f0e-9846-4e72398601f4)

At Queues menu, you can check the queus and the jobs' states related to them. You can `Pause` or `Resume` a queue processing using the menus too
