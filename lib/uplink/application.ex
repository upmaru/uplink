defmodule Uplink.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    oban_config = Application.fetch_env!(:uplink, Oban)

    children =
      [
        {Uplink.Cache, []},
        {Uplink.Repo, []},
        {Oban, oban_config},
        {Plug.Cowboy, scheme: :http, plug: Uplink.Router, port: 4040}
      ]
      |> append_services(Application.get_env(:uplink, :env))
      |> IO.inspect()

    opts = [strategy: :one_for_one, name: Uplink.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp append_services(children, :test), do: children

  defp append_services(children, _) do
    reversed = Enum.reverse(children)

    Enum.reverse([{Uplink.Boot, []} | reversed])
  end
end
