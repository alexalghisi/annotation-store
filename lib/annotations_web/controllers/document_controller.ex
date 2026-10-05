defmodule AnnotationsWeb.DocumentController do
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn
  alias Annotations.Store
  alias AnnotationsWeb.Params

  def index(conn, params) do
    with {:ok, limit} <- Params.int(params, "limit", 50),
         {:ok, after_id} <- Params.int(params, "after", 0) do
      json(conn, Store.list_documents(conn.assigns.tenant_id, limit: limit, after: after_id))
    else
      {:error, message} -> conn |> put_status(400) |> json(%{error: message})
    end
  end

  def create(conn, params) do
    case Store.create_document(conn.assigns.tenant_id, Map.take(params, ["title"])) do
      {:ok, doc} -> conn |> put_status(201) |> json(%{id: doc.id, title: doc.title})
      {:error, cs} -> conn |> put_status(422) |> json(%{errors: Annotations.Errors.messages(cs)})
    end
  end
end
