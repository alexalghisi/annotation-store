defmodule Annotations.StoreTest do
  # Not async: query counting listens to every query, so other tests must not run alongside.
  use Annotations.DataCase, async: false

  defp document!(tenant \\ 1, title \\ "Contract.pdf") do
    {:ok, doc} = Store.create_document(tenant, %{"title" => title})
    doc
  end

  describe "list_documents/2" do
    test "uses two queries no matter how many documents are on the page" do
      docs = for i <- 1..40, do: document!(1, "doc #{i}")
      {:ok, _} = Store.upsert_annotations(hd(docs).id, [annotation(), annotation()])

      {result, queries} = count_queries(fn -> Store.list_documents(1, limit: 40) end)
      assert queries == 2
      assert length(result.documents) == 40
      assert hd(result.documents).annotations == 2
      assert List.last(result.documents).annotations == 0
    end

    test "pages by id and keeps tenants apart" do
      %{id: a} = document!(1)
      %{id: b} = document!(1)
      _other = document!(2)
      assert %{documents: [%{id: ^a}], next: next} = Store.list_documents(1, limit: 1)
      assert %{documents: [%{id: ^b}], next: nil} = Store.list_documents(1, limit: 1, after: next)
    end
  end

  describe "upsert_annotations/2" do
    test "writes a batch in one statement and is idempotent per client_id" do
      doc = document!()
      items = [annotation(%{"page" => 1}), annotation(%{"page" => 2})]

      {{:ok, first}, queries} = count_queries(fn -> Store.upsert_annotations(doc.id, items) end)
      assert queries == 1
      assert length(first) == 2

      retried = Enum.map(items, &Map.put(&1, "kind", "note"))
      {:ok, second} = Store.upsert_annotations(doc.id, retried)
      assert Enum.sort(Enum.map(second, & &1.id)) == Enum.sort(Enum.map(first, & &1.id))

      %{annotations: stored} = Store.list_annotations(doc.id)
      assert Enum.map(stored, & &1.kind) == ["note", "note"]
    end

    test "rejects the whole batch and reports every invalid item by index" do
      doc = document!()
      items = [annotation(), annotation(%{"page" => -1}), annotation(%{"kind" => "doodle"}), %{"page" => 0}]

      assert {:error, {:invalid, errors}} = Store.upsert_annotations(doc.id, items)
      assert Enum.map(errors, & &1.index) == [1, 2, 3]
      assert Enum.at(errors, 2).errors == %{client_id: ["can't be blank"], kind: ["can't be blank"]}
      assert Store.list_annotations(doc.id).annotations == []
    end

    test "limits batch and payload sizes" do
      doc = document!()

      assert {:error, :too_large} =
               Store.upsert_annotations(doc.id, List.duplicate(annotation(), Store.max_batch() + 1))

      huge = annotation(%{"payload" => %{"ink" => String.duplicate("x", 20_000)}})

      assert {:error, {:invalid, [%{errors: %{payload: ["must be at most 16 KB"]}}]}} =
               Store.upsert_annotations(doc.id, [huge])
    end
  end

  describe "list_annotations/2" do
    test "pages with a keyset and filters by page" do
      doc = document!()
      {:ok, _} = Store.upsert_annotations(doc.id, for(p <- [1, 1, 2, 2, 2], do: annotation(%{"page" => p})))

      %{annotations: first, next: next} = Store.list_annotations(doc.id, limit: 3)
      %{annotations: rest, next: nil} = Store.list_annotations(doc.id, limit: 3, after: next)
      assert length(first) == 3 and length(rest) == 2
      assert Enum.map(first ++ rest, & &1.id) == Enum.sort(Enum.map(first ++ rest, & &1.id))
      assert length(Store.list_annotations(doc.id, page: 2).annotations) == 3
    end
  end
end
