defmodule Uplink.Availability do
  alias Uplink.Metrics
  alias Uplink.Pipelines

  alias Uplink.Clients.LXD
  alias Uplink.Clients.Instellar

  alias __MODULE__.Query
  alias __MODULE__.Response
  alias __MODULE__.Resource
  alias __MODULE__.Placeability

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
      %{status: 200, body: %{"responses" => responses}} ->
        resources =
          nodes
          |> Response.parse(responses)
          |> Enum.map(&Resource.parse/1)

        resources = compute_placeability(resources)

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

  defp compute_placeability(resources) do
    template = %{"cpu" => [], "memory" => [], "disk" => []}

    inputs = Enum.reduce(resources, template, &to_inputs/2)

    predictions = Opsmo.predict(Opsmo.CRPM, inputs)

    resources
    |> Enum.zip(predictions)
    |> Enum.map(&patch_with_placeability/1)
  end

  defp to_inputs(resource, acc) do
    %{
      "cpu" =>
        acc["cpu"] ++ [[0.013, Decimal.to_float(resource.used.load_norm_5)]],
      "memory" =>
        acc["memory"] ++
          [
            [
              0.013,
              Decimal.to_float(resource.used.memory),
              Decimal.to_float(resource.total.memory_normalized)
            ]
          ],
      "disk" =>
        acc["disk"] ++ [[0.013, Decimal.to_float(resource.used.storage)]]
    }
  end

  defp patch_with_placeability({resource, prediction}) do
    %{resource | placeability: Placeability.parse(prediction)}
  end
end
