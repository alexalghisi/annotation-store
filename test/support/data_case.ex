defmodule Annotations.DataCase do
  @moduledoc "Runs each test in a transaction that is rolled back, against a real PostgreSQL database."
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Annotations.{Repo, Store}
      import Annotations.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Annotations.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc "Counts the SQL statements `fun` sends to the database."
  def count_queries(fun) do
    ref = make_ref()
    parent = self()
    handler = "count-#{inspect(ref)}"

    :telemetry.attach(handler, [:annotations, :repo, :query], fn _, _, _, _ -> send(parent, {ref, :query}) end, nil)

    try do
      result = fun.()
      {result, drain(ref, 0)}
    after
      :telemetry.detach(handler)
    end
  end

  defp drain(ref, n) do
    receive do
      {^ref, :query} -> drain(ref, n + 1)
    after
      0 -> n
    end
  end

  def annotation(attrs \\ %{}) do
    Map.merge(
      %{
        "client_id" => Ecto.UUID.generate(),
        "page" => 0,
        "kind" => "highlight",
        "payload" => %{"rects" => [[10, 20, 100, 14]]}
      },
      attrs
    )
  end
end
