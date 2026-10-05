defmodule Annotations.Repo.Migrations.CreateDocumentsAndAnnotations do
  use Ecto.Migration

  @partitions 16

  def up do
    create table(:documents) do
      add :tenant_id, :bigint, null: false
      add :title, :text, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:documents, [:tenant_id, :id])

    # Annotations are hash-partitioned by document: every query in the API is scoped to one document,
    # so it touches one partition, and vacuum and index maintenance stay per-partition sized.
    # Identity columns aren't allowed on partitioned tables before PostgreSQL 17, so ids come from a sequence.
    execute "CREATE SEQUENCE annotations_id_seq AS bigint"

    execute """
    CREATE TABLE annotations (
      id           bigint NOT NULL DEFAULT nextval('annotations_id_seq'),
      document_id  bigint NOT NULL REFERENCES documents (id) ON DELETE CASCADE,
      client_id    uuid NOT NULL,
      page         integer NOT NULL CHECK (page >= 0),
      kind         text NOT NULL,
      payload      jsonb NOT NULL DEFAULT '{}',
      inserted_at  timestamptz NOT NULL,
      updated_at   timestamptz NOT NULL,
      PRIMARY KEY (document_id, id),
      UNIQUE (document_id, client_id)
    ) PARTITION BY HASH (document_id)
    """

    for n <- 0..(@partitions - 1) do
      execute "CREATE TABLE annotations_p#{n} PARTITION OF annotations FOR VALUES WITH (MODULUS #{@partitions}, REMAINDER #{n})"
    end

    # Serves "annotations on page N" and keyset pagination by id within a page.
    execute "CREATE INDEX annotations_page ON annotations (document_id, page, id)"
  end

  def down do
    execute "DROP TABLE annotations"
    execute "DROP SEQUENCE annotations_id_seq"
    drop table(:documents)
  end
end
