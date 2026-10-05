import Config

config :annotations, ecto_repos: [Annotations.Repo]

config :annotations, AnnotationsWeb.Endpoint,
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [formats: [json: AnnotationsWeb.ErrorJSON], layout: false],
  url: [host: "localhost"]

config :phoenix, :json_library, Jason

# API key => tenant id. Override in runtime config; these are development keys.
config :annotations, :api_keys, %{"dev-key-tenant-1" => 1, "dev-key-tenant-2" => 2}
config :logger, level: :info

import_config "#{config_env()}.exs"
