# annotation-store

A small Phoenix/Ecto service for storing PDF annotations: highlights, notes, ink and shapes, per page, per document, per tenant. Annotation stores are dominated by a few access patterns: "load the marks for the page I'm looking at", "save what the editor changed, possibly twice because the network blinked", and "list my documents with how many annotations each one has". This repository is about making those three fast and correct as the table grows.

![API calls with idempotent retries and per-item errors, the read-path benchmark on 500,000 annotations, then the test suite](docs/preview.gif)

## Design

**Partitioning.** `annotations` is hash-partitioned 16 ways on `document_id`. Every read and write the API does is scoped to one document, so PostgreSQL only touches one partition. A test asserts this from the query plan (`test/query_plan_test.exs`) rather than trusting it. Ids come from a sequence, because PostgreSQL 16 doesn't allow identity columns on partitioned tables. The primary key is `(document_id, id)`.

**Constant query counts.** `Store.list_documents/2` returns a page of documents with their annotation counts in two queries, whatever the page size. The tests count the queries Ecto sends, so a future N+1 fails CI instead of showing up in production.

**Keyset paging.** Pages are fetched with `WHERE id > $cursor` on the `(document_id, page, id)` index, never `OFFSET`, so page 500 costs the same as page 1.

**Idempotent batch writes.** Clients send a `client_id` (a UUID they generate) with each annotation. A batch is one `INSERT ... ON CONFLICT (document_id, client_id) DO UPDATE` statement, so a retried request returns the same ids instead of creating duplicates. Batches are capped at 1,000 items and payloads at 16 KB. Validation errors are reported per item index, and a batch with any invalid item writes nothing.

**Tenancy.** Each API key belongs to a tenant. Documents of another tenant answer `404`, not `403`, so ids can't be probed.

**Online migrations.** The second migration adds `author_id` and its index the way you would on a live table: `CREATE INDEX ... ON ONLY` the parent, `CREATE INDEX CONCURRENTLY` on each partition, then `ATTACH PARTITION`. It runs outside a transaction and without the migration lock. A test checks that the parent index ends up valid with all 16 partitions attached.

## Numbers

Seeded with 1,000 documents and 500,000 annotations, median of 30 runs, PostgreSQL 16 on the same machine:

| Read path | Time |
| --- | --- |
| Annotations of one document, one page | 0.35 ms |
| Annotations of one document, first 200 | 1.51 ms |
| 50 documents with counts (2 queries) | 6.02 ms |
| 50 documents with counts, naive N+1 (51 queries) | 10.68 ms |

The N+1 gap looks modest here because the database is on localhost. Each extra query is a network round trip, so with a database 1 ms away the naive version costs about 50 ms more, and the two-query version stays where it is.

## API

| Endpoint | |
| --- | --- |
| `GET /api/documents?after=&limit=` | Documents with annotation counts, keyset paged |
| `POST /api/documents` | `{"title": "..."}` |
| `GET /api/documents/:id/annotations?page=&after=&limit=` | Annotations, optionally for one page |
| `POST /api/documents/:id/annotations/batch` | `{"annotations": [{"client_id", "page", "kind", "payload"}]}` upserts |
| `GET /healthz` | |

Requests need `Authorization: Bearer <api key>`. Development keys are in `config/dev.exs`.

## Tech stack

Elixir 1.18, Phoenix 1.7, Ecto 3 with `ecto_sql` and Postgrex, PostgreSQL 16, Jason, ExUnit.

## Running it

```bash
mix setup                      # deps, database, migrations, seeds (1,000 documents x 500 annotations)
mix run priv/bench.exs
mix phx.server                 # http://localhost:4000
```

The database connection is read from `DATABASE_URL`, defaulting to `postgres://postgres:postgres@localhost/annotations_dev`.

## Tests

```bash
mix test
```

## Layout

```
lib/annotations/        schemas, Store (all queries live here), error formatting
lib/annotations_web/    endpoint, router, API key auth, controllers
priv/repo/migrations/   partitioned schema, online index migration
priv/bench.exs          read-path benchmark
test/                   store, query plans, HTTP API
```

## License

MIT
