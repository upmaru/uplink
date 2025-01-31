defmodule Uplink.Availability do
  alias Uplink.Metrics
  alias Uplink.Pipelines

  alias Uplink.Clients.LXD
  alias Uplink.Clients.Instellar

  alias __MODULE__.Query
  alias __MODULE__.Response
  alias __MODULE__.Resource
  alias __MODULE__.Placeability
  alias __MODULE__.Requirement

  defdelegate process_requirement(params),
    to: Requirement.Manager,
    as: :process

  @spec check!(list(%Requirement{})) ::
          {:ok, list(%Resource{})} | {:error, any()}
  def check!(requirements) when is_list(requirements) do
    case get_monitor() do
      %{"attributes" => _attributes} = monitor ->
        check(monitor, requirements)

      {:ok, monitors} ->
        monitors
        |> List.first()
        |> check(requirements)

      _ ->
        raise "No monitor found"
    end
  end

  def check(%{"attributes" => _} = monitor, requirements)
      when is_map(monitor) do
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

        # Extract instance metrics from responses
        nodes_instances_metrics =
          Enum.map(nodes, &extract_node_instances_metrics(&1, responses))

        requirements =
          Enum.map(
            requirements,
            &update_requirement_with_actual_usage(
              &1,
              nodes,
              nodes_instances_metrics
            )
          )

        resources = compute_placeability(resources, requirements)

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

  defp compute_placeability(resources, requirements) do
    template = %{"processing" => [], "memory" => [], "storage" => []}

    inputs = Enum.reduce(resources, template, &to_inputs(&1, &2, requirements))

    predictions = Opsmo.predict(Opsmo.CRPM, inputs)

    resources
    |> Enum.zip(predictions)
    |> Enum.map(&patch_with_placeability/1)
  end

  defp to_inputs(resource, acc, requirements) do
    requirement = Enum.find(requirements, fn r -> r.node == resource.node end)

    zero = Decimal.new("0")

    requested_processing =
      if requirement.actual_processing &&
           Decimal.gt?(requirement.actual_processing, zero) do
        Decimal.to_float(requirement.actual_processing)
      else
        Decimal.to_float(requirement.processing)
      end

    requested_memory =
      if requirement.actual_memory &&
           Decimal.gt?(requirement.actual_memory, zero) do
        Decimal.to_float(requirement.actual_memory)
      else
        Decimal.to_float(requirement.memory)
      end

    requested_storage =
      if requirement.actual_storage &&
           Decimal.gt?(requirement.actual_storage, zero) do
        Decimal.to_float(requirement.actual_storage)
      else
        Decimal.to_float(requirement.storage)
      end

    %{
      "cpu" =>
        acc["processing"] ++
          [[requested_processing, Decimal.to_float(resource.used.load_norm_5)]],
      "memory" =>
        acc["memory"] ++
          [
            [
              requested_memory,
              Decimal.to_float(resource.used.memory),
              Decimal.to_float(resource.total.memory_normalized)
            ]
          ],
      "disk" =>
        acc["storage"] ++
          [[requested_storage, Decimal.to_float(resource.used.storage)]]
    }
  end

  defp patch_with_placeability({resource, prediction}) do
    prediction = %{
      "processing" => prediction.cpu,
      "memory" => prediction.memory,
      "storage" => prediction.disk
    }

    %{resource | placeability: Placeability.parse(prediction)}
  end

  defp extract_node_instances_metrics(node, responses) do
    instances_metrics =
      responses
      |> Enum.flat_map(fn response ->
        aggregations = response["aggregations"]
        aggregations[node.name]["buckets"]
      end)
      |> Enum.group_by(&Map.get(&1, "key"))

    %{"node" => node.name, "metrics" => instances_metrics}
  end

  defp update_requirement_with_actual_usage(
         requirement,
         nodes,
         instance_metrics
       ) do
    metrics =
      instance_metrics
      |> Enum.filter(fn m -> m["node"] == requirement.node end)
      |> Enum.flat_map(fn m -> m["metrics"] end)
      |> Enum.filter(fn {key, _} -> key in requirement.instances end)

    summed_metrics =
      Enum.reduce(
        metrics,
        %{processing: 0.0, memory: 0.0, storage: 0.0},
        fn {_key, values}, acc ->
          processing =
            Enum.find(values, fn v -> Map.has_key?(v, "load_norm_5") end)

          memory =
            Enum.find(values, fn v -> Map.has_key?(v, "memory_used_bytes") end)

          storage =
            Enum.find(values, fn v ->
              Map.has_key?(v, "filesystem_used_bytes")
            end)

          processing = processing["load_norm_5"]
          memory = memory["memory_used_bytes"]
          storage = storage["filesystem_used_bytes"]

          processing = processing["top"]
          memory = memory["top"]
          storage = storage["top"]

          processing = List.first(processing)
          memory = List.first(memory)
          storage = List.first(storage)

          processing = processing["metrics"]["system.load.norm.5"] || 0.0
          memory = memory["metrics"]["system.memory.actual.used.bytes"] || 0.0
          storage = storage["metrics"]["system.filesystem.used.bytes"] || 0.0

          Map.merge(acc, %{
            processing: acc.processing + processing,
            memory: acc.memory + memory,
            storage: acc.storage + storage
          })
        end
      )

    node = Enum.find(nodes, fn n -> n.name == requirement.node end)

    mean_metrics =
      if length(metrics) > 0 do
        %{
          processing: summed_metrics.processing / length(metrics),
          memory: summed_metrics.memory / length(metrics),
          storage: summed_metrics.storage / length(metrics)
        }
      else
        %{processing: 0.0, memory: 0.0, storage: 0.0}
      end

    %{
      requirement
      | actual_processing: Decimal.new("#{mean_metrics.processing}"),
        actual_memory:
          Decimal.new("#{mean_metrics.memory / node.total_memory}"),
        actual_storage:
          Decimal.new("#{mean_metrics.storage / node.total_storage}")
    }
  end
end
