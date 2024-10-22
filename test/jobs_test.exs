defmodule Oban.Console.JobsTest do
  use ExUnit.Case

  alias Oban.Console.Jobs
  alias Oban.Console.Repo
  alias Oban.Console.Storage

  describe "list/0" do
    test "return jobs" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert ObanMock.jobs() == Jobs.list()
    end
  end

  describe "show_list/0" do
    setup do
      System.put_env("OBAN_CONSOLE_JOBS_LAST_OPTS", "")
      System.put_env("OBAN_CONSOLE_JOBS_LAST_IDS", "")

      Storage.delete_profile_file()

      :ok
    end

    test "shows the list" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      assert :ok = Jobs.show_list()
    end

    test "with a profile shows list adding the opts to the profile" do
      Mimic.stub(Repo, :all, fn _ -> ObanMock.jobs() end)

      Storage.find_or_create_profile("API", [])

      assert :ok = Jobs.show_list()

      assert {"API", %{"filters" => [%{"ids" => [], "limit" => 20, "states" => []}]}} =
               Storage.get_profile()

      assert :ok = Jobs.show_list(limit: 50, states: ["scheduled"])

      assert {"API",
              %{
                "filters" => [
                  %{
                    "ids" => [],
                    "limit" => 50,
                    "states" => ["scheduled"]
                  },
                  %{"ids" => [], "limit" => 20, "states" => []}
                ]
              }} = Storage.get_profile()
    end
  end

  describe "debug_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.debug_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :get_job, 1, fn 102_030 -> %Oban.Job{} end)
      Mimic.expect(Repo, :get_job, 1, fn 102_040 -> %Oban.Job{} end)

      assert :ok = Jobs.debug_jobs([102_030, 102_040])
    end

    test "with a single ids" do
      Mimic.expect(Repo, :get_job, 1, fn 102_040 -> %Oban.Job{} end)

      assert :ok = Jobs.debug_jobs(102_040)
    end

    test "with an invalid id" do
      assert :ok = Jobs.debug_jobs("jose")
    end
  end

  describe "cancel_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.cancel_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :cancel_job, 1, fn 102_030 -> %Oban.Job{} end)
      Mimic.expect(Repo, :cancel_job, 1, fn 102_040 -> %Oban.Job{} end)

      assert :ok = Jobs.cancel_jobs([102_030, 102_040])
    end

    test "with a single ids" do
      Mimic.expect(Repo, :cancel_job, 1, fn 102_040 -> %Oban.Job{} end)

      assert :ok = Jobs.cancel_jobs(102_040)
    end

    test "with an invalid id" do
      assert :ok = Jobs.cancel_jobs("jose")
    end
  end

  describe "retry_jobs/1" do
    test "with an empty list of ids" do
      assert :ok = Jobs.retry_jobs([])
    end

    test "with a list of ids" do
      Mimic.expect(Repo, :retry_job, 1, fn 102_030 -> %Oban.Job{} end)
      Mimic.expect(Repo, :retry_job, 1, fn 102_040 -> %Oban.Job{} end)

      assert :ok = Jobs.retry_jobs([102_030, 102_040])
    end

    test "with a single ids" do
      Mimic.expect(Repo, :retry_job, 1, fn 102_040 -> %Oban.Job{} end)

      assert :ok = Jobs.retry_jobs(102_040)
    end

    test "with an invalid id" do
      assert :ok = Jobs.retry_jobs("jose")
    end
  end
end
