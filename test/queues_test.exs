defmodule Oban.Console.QueuesTest do
  use ExUnit.Case

  alias Oban.Console.Queues
  alias Oban.Console.Repo

  describe "list/0" do
    test "return queues fields" do
      Mimic.stub(Repo, :queues, fn -> ObanMock.queues() end)

      assert ObanMock.queues() == Queues.list()
    end
  end

  describe "show_list/0" do
    test "shows the list" do
      Mimic.stub(Repo, :queues, fn -> ObanMock.queues() end)

      assert :ok = Queues.show_list()
    end
  end

  describe "pause_queues/1" do
    test "with an empty list of names" do
      assert :ok = Queues.pause_queues([])
    end

    test "with a list of names" do
      Mimic.expect(Repo, :pause_queue, 2, fn _ -> :ok end)

      assert :ok = Queues.pause_queues(["default", "searching"])
    end

    test "with a single name" do
      Mimic.expect(Repo, :pause_queue, 2, fn _ -> :ok end)

      assert :ok = Queues.pause_queues("default")
    end

    test "with an invalid name" do
      assert :ok = Queues.pause_queues(1)
    end
  end

  describe "resume_queues/1" do
    test "with an empty list of names" do
      assert :ok = Queues.resume_queues([])
    end

    test "with a list of names" do
      Mimic.expect(Repo, :resume_queue, 2, fn _ -> :ok end)

      assert :ok = Queues.resume_queues(["default", "searching"])
    end

    test "with a single name" do
      Mimic.expect(Repo, :resume_queue, 2, fn _ -> :ok end)

      assert :ok = Queues.resume_queues("default")
    end

    test "with an invalid name" do
      assert :ok = Queues.resume_queues(1)
    end
  end
end
