defmodule Annotations.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [Annotations.Repo, AnnotationsWeb.Endpoint]
    Supervisor.start_link(children, strategy: :one_for_one, name: Annotations.Supervisor)
  end
end
