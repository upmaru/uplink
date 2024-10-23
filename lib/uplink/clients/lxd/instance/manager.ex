defmodule Uplink.Clients.LXD.Instance.Manager do
  alias Uplink.{
    Clients
  }

  alias Clients.LXD
  alias LXD.Instance

  def list(options \\ []) do
    project = Keyword.get(options, :project, nil)
    recursion = Keyword.get(options, :recursion, 1)

    if recursion < 1 do
      raise "recursion must be greater than 0 and less than 3 but got #{recursion}"
    end

    project_query =
      if project do
        [project: project]
      else
        [{"all-projects", true}]
      end

    query = [{:recursion, recursion} | project_query]

    LXD.client()
    |> Lexdee.list_instances(query: query)
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
