import Config

config :annotations, Annotations.Repo,
  url: System.get_env("DATABASE_URL", "postgres://postgres:postgres@localhost/annotations_test"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :annotations, AnnotationsWeb.Endpoint,
  http: [port: 4002],
  server: false,
  secret_key_base: String.duplicate("test-only-secret", 4)

config :logger, level: :warning
