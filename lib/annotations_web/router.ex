defmodule AnnotationsWeb.Router do
  use Phoenix.Router
  import Plug.Conn

  pipeline :api do
    plug :accepts, ["json"]
    plug AnnotationsWeb.Auth
  end

  get "/healthz", AnnotationsWeb.HealthController, :show

  scope "/api", AnnotationsWeb do
    pipe_through :api
    get "/documents", DocumentController, :index
    post "/documents", DocumentController, :create
    get "/documents/:id/annotations", AnnotationController, :index
    post "/documents/:id/annotations/batch", AnnotationController, :batch
  end
end
