defmodule Uplink.Cluster do
  def get(key) do
    Application.get_env(:uplink, __MODULE__)
    |> Keyword.get(key)
  end
end
