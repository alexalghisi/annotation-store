# Seeds a development database with realistic volume:
#   SEED_DOCUMENTS=1000 SEED_ANNOTATIONS=500 mix run priv/repo/seeds.exs
alias Annotations.{Repo, Store}

documents = String.to_integer(System.get_env("SEED_DOCUMENTS", "1000"))
per_document = String.to_integer(System.get_env("SEED_ANNOTATIONS", "500"))
kinds = Annotations.Annotation.kinds()

for d <- 1..documents do
  {:ok, doc} = Store.create_document(rem(d, 3) + 1, %{"title" => "Document #{d}.pdf"})

  1..per_document
  |> Enum.map(fn i ->
    %{
      "client_id" => Ecto.UUID.generate(),
      "page" => rem(i, 40),
      "kind" => Enum.at(kinds, rem(i, length(kinds))),
      "payload" => %{"rects" => [[rem(i * 37, 500), rem(i * 91, 700), 120, 14]], "color" => "#ffd400"}
    }
  end)
  |> Enum.chunk_every(Store.max_batch())
  |> Enum.each(fn batch -> {:ok, _} = Store.upsert_annotations(doc.id, batch) end)

  if rem(d, 100) == 0, do: IO.puts("#{d} documents")
end

Repo.query!("ANALYZE documents")
Repo.query!("ANALYZE annotations")
IO.puts("seeded #{documents} documents with #{per_document} annotations each")
