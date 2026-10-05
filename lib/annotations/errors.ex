defmodule Annotations.Errors do
  @moduledoc "Turns changeset errors into plain messages, filling in placeholders such as %{number}."
  def messages(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r/%{(\w+)}/, message, fn placeholder, key ->
        case Enum.find(opts, fn {k, _} -> Atom.to_string(k) == key end) do
          {_, value} -> to_string(value)
          nil -> placeholder
        end
      end)
    end)
  end
end
