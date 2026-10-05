import Config

config :annotations, Annotations.Repo,
  url: System.get_env("DATABASE_URL", "postgres://postgres:postgres@localhost/annotations_dev"),
  pool_size: 10

config :annotations, AnnotationsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT", "4000"))],
  server: true,
  secret_key_base: String.duplicate("dev-only-secret-", 4)
