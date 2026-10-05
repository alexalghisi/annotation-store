defmodule Annotations.Annotation do
  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(highlight note ink stamp link)

  @primary_key false
  @timestamps_opts [type: :utc_datetime_usec]
  schema "annotations" do
    field :id, :id, primary_key: true, read_after_writes: true
    field :document_id, :id, primary_key: true
    field :client_id, Ecto.UUID
    field :page, :integer
    field :kind, :string
    field :payload, :map, default: %{}
    field :author_id, :integer
    timestamps()
  end

  @doc "Validates one annotation from a batch. Payloads are limited so one client can't bloat a partition."
  def changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:client_id, :page, :kind, :payload, :author_id])
    |> validate_required([:client_id, :page, :kind])
    |> validate_number(:page, greater_than_or_equal_to: 0)
    |> validate_inclusion(:kind, @kinds)
    |> validate_change(:payload, fn :payload, payload ->
      if byte_size(Jason.encode!(payload)) > 16_384, do: [payload: "must be at most 16 KB"], else: []
    end)
  end

  def kinds, do: @kinds
end
