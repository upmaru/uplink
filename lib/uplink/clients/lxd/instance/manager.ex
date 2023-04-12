defmodule Uplink.Clients.LXD.Instance.Manager do
  alias Uplink.{
    Clients
  }

  alias Clients.LXD
  alias LXD.Instance

  def list(project) do
    LXD.client()
    |> Lexdee.list_instances(query: [recursion: 1, project: project])
    |> case do
      {:ok, %{body: instances}} ->
        instances =
          instances
          |> Enum.map(fn instance ->
            Instance.parse(instance)
          end)

        instances

      error ->
        error
    end
  end
end
