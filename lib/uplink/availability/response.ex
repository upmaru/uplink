defmodule Uplink.Availability.Response do
  alias Uplink.Availability.Query

  def parse(nodes, responses) when is_list(responses) do
    retrieval_keys = Query.retrieval_keys()

    params = %{
      retrieval_keys: retrieval_keys,
      responses: responses
    }

    Enum.map(nodes, &parse_node(&1, params))
  end

  defp parse_node(node, %{retrieval_keys: retrieval_keys, responses: responses}) do
    usage_params =
      Enum.filter(responses, fn response ->
        %{"aggregations" => aggregations} = response

        Map.has_key?(aggregations, node.name)
      end)
      |> Enum.reduce(%{}, fn response, acc ->
        %{"aggregations" => aggregations} = response

        relevant_key =
          aggregations
          |> Map.keys()
          |> Enum.filter(&Enum.member?(retrieval_keys, &1))
          |> List.first()

        result =
          Map.get(aggregations, relevant_key)
          |> Map.fetch!("value")

        Map.put(acc, relevant_key, result)
      end)

    load_norm_5 = Map.get(usage_params, "load_norm_5", 0.0)
    used_memory_bytes = Map.get(usage_params, "memory_used_bytes", 0)
    used_storage_bytes = Map.get(usage_params, "filesystem_used_bytes", 0)

    memory_normalized =
      node.total_memory
      # Convert bytes to megabytes
      |> div(1024 * 1024)
      |> trunc()
      |> Opsmo.CRPM.normalize_memory()
      |> Nx.to_number()

    %{
      "node" => node.name,
      "total" => %{
        "cpu_cores" => node.cpu_cores_count,
        "memory_bytes" => node.total_memory,
        "memory_normalized" => memory_normalized,
        "storage_bytes" => node.total_storage
      },
      "used" => %{
        "load_norm_5" => load_norm_5,
        "memory" => normalize_value(used_memory_bytes, node.total_memory),
        "storage" => normalize_value(used_storage_bytes, node.total_storage)
      },
      "available" => %{
        "processing" => 1 - load_norm_5,
        "memory" => compute_available(used_memory_bytes, node.total_memory),
        "storage" => compute_available(used_storage_bytes, node.total_storage)
      }
    }
  end

  defp normalize_value(used, total) do
    used = Decimal.new("#{used}")
    total = Decimal.new("#{total}")
    Decimal.div(used, total)
  end

  defp compute_available(used, total) do
    Decimal.sub(Decimal.new("1"), normalize_value(used, total))
  end
end
