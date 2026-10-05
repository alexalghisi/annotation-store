defmodule AnnotationsWeb.Auth do
  @moduledoc "Resolves the tenant from an API key: `Authorization: Bearer <key>`, keys configured as key => tenant id."
  import Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    keys = Application.get_env(:annotations, :api_keys, %{})

    with ["Bearer " <> key] <- get_req_header(conn, "authorization"),
         {:ok, tenant_id} <- Map.fetch(keys, key) do
      assign(conn, :tenant_id, tenant_id)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, Jason.encode!(%{error: "invalid or missing API key"}))
        |> halt()
    end
  end
end
