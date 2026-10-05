import Config

if config_env() == :prod do
  config :annotations, Annotations.Repo,
    url: System.fetch_env!("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

  config :annotations, AnnotationsWeb.Endpoint,
    http: [ip: {0, 0, 0, 0}, port: String.to_integer(System.get_env("PORT", "4000"))],
    server: true,
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end
