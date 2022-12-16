defmodule Uplink.Clients.Caddy do
  alias __MODULE__.{
    Config
  }

  def get_config do
    case Config.get() do
      {:ok, nil} ->
        {:ok, nil}

      {:ok, body} ->
        {:ok, Config.parse(body)}

      error ->
        error
    end
  end

  defdelegate load_config(params), to: __MODULE__.Config, as: :load

  def config(key) do
    Application.get_env(:uplink, __MODULE__)
    |> Keyword.get(key)
  end
end
