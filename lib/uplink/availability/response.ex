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

    %{
      "node" => node.name,
      "usage" => %{
        "load_norm_5" => Map.get(usage_params, "load_norm_5", 0.0),
        "memory_bytes" => Map.get(usage_params, "memory_used_bytes", 0),
        "storage_bytes" => Map.get(usage_params, "filesystem_used_bytes", 0)
      },
      "available" => %{
        "cpu_cores" => node.cpu_cores_count,
        "memory_bytes" => node.total_memory,
        "storage_bytes" => node.total_storage
      }
    }
  end
end
