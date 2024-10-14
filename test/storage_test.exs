defmodule Oban.Console.StorageTest do
	use ExUnit.Case

	alias Oban.Console.Storage

  describe "get_last_jobs_opts/0" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
      System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
      System.put_env("OBAN_CONSOLE_PROFILE", "")
    end

    test "returns empty without last options saved" do
      assert [] = Storage.get_last_jobs_opts()
    end

    test "returns last options saved" do
      opts = [limit: 50, states: [:scheduled]]

      Storage.set_last_jobs_opts(opts)

      assert opts = Storage.get_last_jobs_opts()
    end
  end
end
