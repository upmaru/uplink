defmodule Uplink.Availability do
  alias Uplink.Metrics
  alias Uplink.Pipelines

  alias Uplink.Clients.LXD
  alias Uplink.Clients.Instellar

  alias __MODULE__.Query
  alias __MODULE__.Response
  alias __MODULE__.Resource

  def check! do
    case get_monitor() do
      %{"attributes" => _attributes} = monitor ->
        check(monitor)

      {:ok, monitors} ->
        monitors
        |> List.first()
        |> check()

      _ ->
        raise "No monitor found"
    end
  end

  def check(%{"attributes" => _} = monitor) when is_map(monitor) do
    indices =
      Query.index_types()
      |> Enum.map(&Metrics.index/1)

    nodes =
      LXD.list_cluster_members()
      |> Enum.map(fn member ->
        LXD.get_node(member.server_name)
      end)

    query = Query.build(nodes, indices)

    Metrics.query!(monitor, query)
    |> case do
      %{status: 200, body: %{"responses" => responses} = body} ->
        File.write!("availability.json", Jason.encode!(body))

        resources =
          nodes
          |> Response.parse(responses)
          |> Enum.map(&Resource.parse/1)

        {:ok, resources}

      _ ->
        {:error, :could_not_query_metrics}
    end
  end

  defp get_monitor do
    monitors = Pipelines.get_monitors(:metrics)

    if monitors == [] do
      Instellar.list_monitors()
    else
      List.first(monitors)
    end
  end
end
