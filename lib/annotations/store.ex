defmodule Annotations.Store do
  @moduledoc """
  Data access for documents and annotations. Every function issues a fixed number of queries,
  whatever the page or batch size: no per-row lookups (N+1), no unbounded reads.
  """
  import Ecto.Query
  alias Annotations.{Annotation, Document, Repo}

  @max_page 500
  @max_batch 1_000

  def max_batch, do: @max_batch

  def create_document(tenant_id, attrs) do
    %Document{} |> Document.changeset(Map.put(attrs, "tenant_id", tenant_id)) |> Repo.insert()
  end

  def get_document(tenant_id, id) do
    Repo.one(from d in Document, where: d.id == ^id and d.tenant_id == ^tenant_id)
  end

  @doc """
  A page of a tenant's documents with their annotation counts, in two queries: one for the page
  of documents (keyset by id), one grouped count for just those documents.
  """
  def list_documents(tenant_id, opts \\ []) do
    limit = opts |> Keyword.get(:limit, 50) |> min(@max_page)
    after_id = Keyword.get(opts, :after, 0)

    documents =
      Repo.all(
        from d in Document,
          where: d.tenant_id == ^tenant_id and d.id > ^after_id,
          order_by: d.id,
          limit: ^(limit + 1)
      )

    {page, more?} = split(documents, limit)
    ids = Enum.map(page, & &1.id)

    counts =
      Repo.all(
        from a in Annotation,
          where: a.document_id in ^ids,
          group_by: a.document_id,
          select: {a.document_id, count(a.id)}
      )
      |> Map.new()

    %{
      documents: Enum.map(page, &%{id: &1.id, title: &1.title, annotations: Map.get(counts, &1.id, 0)}),
      next: if(more?, do: List.last(page).id)
    }
  end

  @doc """
  Annotations of one document, optionally one page of it, by keyset pagination on id.
  The query is scoped to one document, so PostgreSQL scans only that document's partition.
  """
  def list_annotations(document_id, opts \\ []) do
    limit = opts |> Keyword.get(:limit, 200) |> min(@max_page)
    after_id = Keyword.get(opts, :after, 0)

    query =
      from a in Annotation,
        where: a.document_id == ^document_id and a.id > ^after_id,
        order_by: a.id,
        limit: ^(limit + 1)

    query = if page = Keyword.get(opts, :page), do: where(query, [a], a.page == ^page), else: query
    {items, more?} = query |> Repo.all() |> split(limit)
    %{annotations: items, next: if(more?, do: List.last(items).id)}
  end

  @doc """
  Inserts or updates a batch in one statement. Clients send their own `client_id`, so a retried
  request updates the same rows instead of duplicating them. The whole batch is validated first;
  nothing is written if any item is invalid.
  """
  def upsert_annotations(document_id, items) when is_list(items) do
    cond do
      items == [] ->
        {:ok, []}

      length(items) > @max_batch ->
        {:error, :too_large}

      true ->
        changesets = Enum.map(items, &Annotation.changeset/1)

        case invalid(changesets) do
          [] ->
            now = DateTime.utc_now()

            rows =
              changesets
              |> Enum.map(&Ecto.Changeset.apply_changes/1)
              |> Enum.uniq_by(& &1.client_id)
              |> Enum.map(fn a ->
                %{
                  document_id: document_id,
                  client_id: a.client_id,
                  page: a.page,
                  kind: a.kind,
                  payload: a.payload,
                  author_id: a.author_id,
                  inserted_at: now,
                  updated_at: now
                }
              end)

            {_count, returned} =
              Repo.insert_all(Annotation, rows,
                on_conflict: {:replace, [:page, :kind, :payload, :author_id, :updated_at]},
                conflict_target: [:document_id, :client_id],
                returning: [:id, :client_id]
              )

            {:ok, returned}

          errors ->
            {:error, {:invalid, errors}}
        end
    end
  end

  defp invalid(changesets) do
    changesets
    |> Enum.with_index()
    |> Enum.reject(fn {cs, _} -> cs.valid? end)
    |> Enum.map(fn {cs, index} ->
      %{index: index, errors: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)}
    end)
  end

  defp split(rows, limit), do: {Enum.take(rows, limit), length(rows) > limit}
end
