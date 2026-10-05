defmodule AnnotationsWeb.ConnCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Annotations.DataCase, only: [annotation: 0, annotation: 1]
      @endpoint AnnotationsWeb.Endpoint

      def api(key \\ "dev-key-tenant-1") do
        build_conn()
        |> put_req_header("authorization", "Bearer " <> key)
        |> put_req_header("accept", "application/json")
      end
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Annotations.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
