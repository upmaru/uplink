defmodule Uplink.Clients.LXD.Instance.Manager do
  alias Uplink.{
    Clients
  }

  alias Clients.LXD
  alias LXD.Instance


  def list do
    LXD.client()
    |> Lexdee.list_instances(query: [{:recursion, 1}, {"all-projects", true}])
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
