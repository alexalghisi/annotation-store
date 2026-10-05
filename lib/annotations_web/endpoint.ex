defmodule AnnotationsWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :annotations

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason, length: 8_000_000
  plug AnnotationsWeb.Router
end
