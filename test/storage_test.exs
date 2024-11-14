defmodule Oban.Console.StorageTest do
  use ExUnit.Case

  alias Oban.Console.Storage

  describe "get_last_jobs_opts/0" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    end

    test "returns empty without last options saved" do
      assert [] = Storage.get_last_jobs_opts()
    end

    test "returns last options saved" do
      opts = [limit: 50, states: ["scheduled"]]

      Storage.set_last_jobs_opts(opts)

      assert ^opts = Storage.get_last_jobs_opts()
    end
  end

  describe "set_last_jobs_opts/1" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
    end

    test "saves options" do
      opts = [limit: 50, states: ["scheduled"]]

      Storage.set_last_jobs_opts(opts)

      assert ^opts = Storage.get_last_jobs_opts()
    end

    test "updates options" do
      opts = [limit: 50, states: ["scheduled"]]
      new_opts = [limit: 100, states: ["scheduled", "completed"]]

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

  describe "find_or_create_profile/2" do
    setup do
      System.put_env("OBAN_CONSOLE_PROFILE", "")

      Storage.delete_profile_file()

      :ok
    end

    test "returns nil when name is nil" do
      assert nil == Storage.find_or_create_profile(nil, [])
    end

    test "returns nil when name is empty" do
      assert nil == Storage.find_or_create_profile("", [])
    end

    test "creates profile when name is not found" do
      profiles = [{1, "default"}, {2, "matching api"}]
      assert :ok = Storage.find_or_create_profile("search api", profiles)

      assert "search api" = System.get_env("OBAN_CONSOLE_PROFILE")
      assert "search api" = Storage.get_profile_name()
      assert {"search api", %{"filters" => []}} = Storage.get_profile()
    end
  end

  describe "add_job_filter_history/1" do
    setup do
      System.put_env("OBAN_CONSOLE_PROFILE", "")

      Storage.delete_profile_file()

      :ok
    end

    test "adds filters to the selected profile" do
      assert :ok = Storage.find_or_create_profile("search api", [])
      assert :ok = Storage.add_job_filter_history(limit: 50)
      assert :ok = Storage.add_job_filter_history(states: ["available"])

      assert {"search api", %{"filters" => [%{"states" => ["available"]}, %{"limit" => 50}]}} = Storage.get_profile()
    end

    test "skips adding filters when there isn't profile selected" do
      assert :ok = Storage.add_job_filter_history(limit: 50)
      assert :ok = Storage.add_job_filter_history(states: ["available"])

      assert nil == Storage.get_profile()
    end
  end
end
