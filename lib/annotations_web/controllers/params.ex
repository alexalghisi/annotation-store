defmodule AnnotationsWeb.Params do
  @moduledoc "Parses untrusted query parameters into integers, rejecting garbage instead of crashing."
  def int(params, key, default \\ nil) do
    case Map.get(params, key) do
      nil ->
        {:ok, default}

      value when is_binary(value) ->
        case Integer.parse(value) do
          {n, ""} when n >= 0 -> {:ok, n}
          _ -> {:error, "#{key} must be a non-negative integer"}
        end

      _ ->
        {:error, "#{key} must be a non-negative integer"}
    end
  end
end
