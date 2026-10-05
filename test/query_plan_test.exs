defmodule Annotations.QueryPlanTest do
  @moduledoc "Guards the properties the schema was designed for, so a later change can't silently undo them."
  use Annotations.DataCase, async: true
  import Ecto.Query
  alias Annotations.Annotation

  test "reading one document's annotations touches a single partition" do
    query = from a in Annotation, where: a.document_id == ^42 and a.page == ^3, order_by: a.id, limit: 100
    plan = Ecto.Adapters.SQL.explain(Repo, :all, query)
    partitions = Regex.scan(~r/annotations_p\d+/, plan) |> List.flatten() |> Enum.uniq()
    assert length(partitions) == 1, "expected partition pruning, got:\n#{plan}"
  end

  test "the author index added without locking writes is valid on every partition" do
    %{rows: [[valid, attached]]} =
      Repo.query!("""
      SELECT i.indisvalid, (SELECT count(*) FROM pg_inherits WHERE inhparent = 'annotations_author'::regclass)
      FROM pg_index i WHERE i.indexrelid = 'annotations_author'::regclass
      """)

    assert valid
    assert attached == 16
  end
end
