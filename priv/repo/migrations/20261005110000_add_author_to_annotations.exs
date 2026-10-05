defmodule Annotations.Repo.Migrations.AddAuthorToAnnotations do
  @moduledoc """
  Adds `author_id` and an index on it without blocking writes on a large, live table.

  - The column is nullable with no default, so adding it is a catalog-only change.
  - CREATE INDEX CONCURRENTLY doesn't work on a partitioned table, so the parent index is created
    ON ONLY the parent (invalid and empty), each partition is indexed concurrently, and the partition
    indexes are attached. Once all are attached, PostgreSQL marks the parent index valid.
  - Concurrent index builds can't run inside a transaction, hence the two module attributes.
  """
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  @partitions 16

  def up do
    execute "ALTER TABLE annotations ADD COLUMN IF NOT EXISTS author_id bigint"
    execute "CREATE INDEX IF NOT EXISTS annotations_author ON ONLY annotations (document_id, author_id)"

    for n <- 0..(@partitions - 1) do
      execute "CREATE INDEX CONCURRENTLY IF NOT EXISTS annotations_p#{n}_author ON annotations_p#{n} (document_id, author_id)"
      execute "ALTER INDEX annotations_author ATTACH PARTITION annotations_p#{n}_author"
    end
  end

  def down do
    execute "DROP INDEX IF EXISTS annotations_author"
    execute "ALTER TABLE annotations DROP COLUMN IF EXISTS author_id"
  end
end
