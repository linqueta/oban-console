defmodule Oban.Console.StorageTest do
  use ExUnit.Case

  alias Oban.Console.Storage

  # setup do
  #   System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
  #   System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
  #   System.put_env("OBAN_CONSOLE_PROFILE", "")
  # end

  describe "get_last_jobs_opts/0" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    end

    test "returns empty without last options saved" do
      assert [] = Storage.get_last_jobs_opts()
    end

    test "returns last options saved" do
      opts = [states: ["scheduled"], limit: 50]

      Storage.set_last_jobs_opts(opts)

      assert ^opts = Storage.get_last_jobs_opts()
    end
  end

  describe "set_last_jobs_opts/1" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    end

    test "saves options" do
      opts = [states: ["scheduled"], limit: 50]

      Storage.set_last_jobs_opts(opts)

      assert ^opts = Storage.get_last_jobs_opts()
    end

    test "updates options" do
      opts = [states: ["scheduled"], limit: 50]
      new_opts = [states: ["scheduled", "completed"], limit: 100]

      Storage.set_last_jobs_opts(opts)
      Storage.set_last_jobs_opts(new_opts)

      assert ^new_opts = Storage.get_last_jobs_opts()
    end
  end
end
