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

  describe "get_last_jobs_ids/0" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    end

    test "returns empty without last ids saved" do
      assert [] = Storage.get_last_jobs_ids()
    end

    test "returns last ids saved" do
      ids = [1, 2, 3]

      Storage.set_last_jobs_ids(ids)

      assert ^ids = Storage.get_last_jobs_ids()
    end
  end

  describe "set_last_jobs_ids/1" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")
    end

    test "saves ids" do
      ids = [1, 2, 3]

      Storage.set_last_jobs_ids(ids)

      assert ^ids = Storage.get_last_jobs_ids()
    end

    test "updates ids" do
      ids = [1, 2, 3]
      new_ids = [4, 5, 6]

      Storage.set_last_jobs_ids(ids)
      Storage.set_last_jobs_ids(new_ids)

      assert ^new_ids = Storage.get_last_jobs_ids()
    end
  end
end
