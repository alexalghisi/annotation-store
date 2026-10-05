defmodule Annotations.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @timestamps_opts [type: :utc_datetime_usec]
  schema "documents" do
    field :tenant_id, :integer
    field :title, :string
    timestamps()
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [:tenant_id, :title])
    |> validate_required([:tenant_id, :title])
    |> validate_length(:title, max: 500)
  end
end
