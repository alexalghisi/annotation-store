defmodule AnnotationsWeb.AnnotationController do
  use Phoenix.Controller, formats: [:json]
  import Plug.Conn
  alias Annotations.Store
  alias AnnotationsWeb.Params

  def index(conn, %{"id" => id} = params) do
    with {:ok, document} <- document(conn, id),
         {:ok, limit} <- Params.int(params, "limit", 200),
         {:ok, after_id} <- Params.int(params, "after", 0),
         {:ok, page} <- Params.int(params, "page") do
      result = Store.list_annotations(document.id, limit: limit, after: after_id, page: page)
      json(conn, %{annotations: Enum.map(result.annotations, &to_json/1), next: result.next})
    else
      error -> fail(conn, error)
    end
  end

  def batch(conn, %{"id" => id} = params) do
    with {:ok, document} <- document(conn, id),
         items when is_list(items) <- Map.get(params, "annotations", :missing),
         {:ok, saved} <- Store.upsert_annotations(document.id, items) do
      json(conn, %{saved: Enum.map(saved, &%{id: &1.id, client_id: &1.client_id})})
    else
      :missing -> fail(conn, {:error, "body must be {\"annotations\": [...]}"})
      error -> fail(conn, error)
    end
  end

  defp document(conn, id) do
    with {:ok, document_id} <- Params.int(%{"id" => id}, "id"),
         %{} = document <- Store.get_document(conn.assigns.tenant_id, document_id) do
      {:ok, document}
    else
      # Another tenant's document looks exactly like a missing one.
      _ -> {:not_found}
    end
  end

  defp to_json(a), do: Map.take(a, [:id, :client_id, :page, :kind, :payload, :author_id, :updated_at])

  defp fail(conn, {:not_found}), do: conn |> put_status(404) |> json(%{error: "document not found"})

  defp fail(conn, {:error, :too_large}),
    do: conn |> put_status(413) |> json(%{error: "at most #{Store.max_batch()} annotations per batch"})

  defp fail(conn, {:error, {:invalid, errors}}), do: conn |> put_status(422) |> json(%{errors: errors})
  defp fail(conn, {:error, message}) when is_binary(message), do: conn |> put_status(400) |> json(%{error: message})
end
