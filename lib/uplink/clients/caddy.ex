defmodule Uplink.Clients.Caddy do
  alias __MODULE__.{
    Config
  }

  alias Uplink.Packages.Install

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

  def schedule_config_reload(%Install{id: install_id}, options \\ []) do
    actor_id = Keyword.get(options, :actor_id)

    params =
      if actor_id do
        %{install_id: install_id, actor_id: actor_id}
      else
        %{install_id: install_id}
      end

    params
    |> Config.Reload.new(schedule_in: 1)
    |> Oban.insert()
  end

  defdelegate load_config(params), to: __MODULE__.Config, as: :load

  defdelegate build_new_config(), to: __MODULE__.Config.Builder, as: :new

  def config(key) do
    Application.get_env(:uplink, __MODULE__)
    |> Keyword.get(key)
  end
end
