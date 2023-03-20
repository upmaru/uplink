defmodule Uplink.Data do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    oban_config = Application.fetch_env!(:uplink, Oban)

    children =
      [
        {Uplink.Repo, []},
        {Oban, oban_config}
      ]
      |> append_live_only_services(Application.get_env(:uplink, :environment))

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp append_live_only_services(children, env) when env in [:test, :dev],
    do: children

  defp append_live_only_services(children, _) do
    children ++
      [
        {Uplink.Boot, []}
      ]
  end
end
