# Measures the main read paths on a seeded database and compares the documents list with a naive N+1 version.
#   mix run priv/bench.exs
import Ecto.Query
alias Annotations.{Annotation, Document, Repo, Store}

defmodule Bench do
  def median_ms(fun, runs \\ 30) do
    fun.()

    times =
      for _ <- 1..runs do
        {us, _} = :timer.tc(fun)
        us / 1000
      end

    times |> Enum.sort() |> Enum.at(div(runs, 2))
  end
end

%{rows: [[total]]} = Repo.query!("SELECT count(*) FROM annotations")
doc_id = Repo.one(from d in Document, where: d.tenant_id == 1, order_by: [desc: d.id], limit: 1, select: d.id)

naive = fn ->
  docs = Repo.all(from d in Document, where: d.tenant_id == 1, order_by: d.id, limit: 50)
  Enum.map(docs, fn d -> {d.id, Repo.aggregate(from(a in Annotation, where: a.document_id == ^d.id), :count)} end)
end

results = [
  {"annotations of one document, one page (#{doc_id})", fn -> Store.list_annotations(doc_id, page: 7) end},
  {"annotations of one document, first 200", fn -> Store.list_annotations(doc_id, limit: 200) end},
  {"50 documents with counts (2 queries)", fn -> Store.list_documents(1, limit: 50) end},
  {"50 documents with counts, naive N+1 (51 queries)", naive}
]

IO.puts("#{total} annotations across #{Repo.aggregate(Document, :count)} documents, median of 30 runs\n")

for {name, fun} <- results do
  IO.puts(String.pad_trailing(name, 52) <> :erlang.float_to_binary(Bench.median_ms(fun), decimals: 2) <> " ms")
end
