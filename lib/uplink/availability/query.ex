defmodule Uplink.Availability.Query do
  alias Uplink.Clients.LXD.Node
  alias Uplink.Availability.Attribute

  @metrics_mappings %{
    "metrics-system.memory-" => :memory,
    "metrics-system.load-" => :load,
    "metrics-system.filesystem-" => :filesystem
  }

  @metrics_aggregate_attributes %{
    memory: [
      %Attribute{
        name: "memory_used_bytes",
        field: "system.memory.actual.used.bytes"
      }
    ],
    load: [
      %Attribute{
        name: "load_norm_5",
        field: "system.load.norm.5"
      }
    ],
    filesystem: [
      %Attribute{
        name: "filesystem_used_bytes",
        field: "system.filesystem.used.bytes"
      }
    ]
  }

  def index_types do
    Map.values(@metrics_mappings)
  end

  @spec build([Node.t()] | Member.t(), [String.t()]) :: String.t()
  def build(nodes, indices) when is_list(members) do
    nodes
    |> Enum.flat_map(fn node ->
      build(node, indices)
    end)
    |> Enum.join("\n")
  end

  def build(%Node{name: key}, indices)
      when is_list(indices) do
    valid_prefixes = Map.keys(@metrics_mappings)

    indices
    |> Enum.filter(fn index ->
      Enum.any?(valid_prefixes, fn prefix ->
        index =~ prefix
      end)
    end)
    |> Enum.flat_map(fn index ->
      {_prefix, type} =
        Enum.find(@metrics_mappings, fn {prefix, _type} ->
          index =~ prefix
        end)

      attributes = Map.fetch!(@metrics_aggregate_attributes, type)

      aggregates = %{
        key => %{
          terms: %{
            field: "host.name",
            size: 1000
          },
          aggs: Enum.reduce(attributes, %{}, &build_aggregate/2)
        }
      }

      query = %{
        size: 0,
        query: %{
          term: %{
            "cloud.instance.id" => key
          }
        },
        aggs: Enum.reduce(attributes, aggregates, &build_sum(key, &1, &2))
      }

      [%{index: index}, query]
    end)
    |> Enum.map(&Jason.encode_to_iodata!/1)
    |> Enum.join("\n")
  end

  def retrieval_keys do
    @metrics_aggregate_attributes
    |> Map.values()
    |> List.flatten()
    |> Enum.map(& &1.name)
  end

  defp build_aggregate(attribute, acc) do
    query = %{
      top_metrics: %{
        metrics: [
          %{field: attribute.field}
        ],
        sort: %{
          "@timestamp" => "desc"
        },
        size: 1
      }
    }

    Map.put(acc, attribute.name, query)
  end

  defp build_sum(key, attribute, acc) do
    sum = %{
      sum_bucket: %{
        buckets_path: "#{key}>#{attribute.name}[#{attribute.field}]"
      }
    }

    Map.put(acc, attribute.name, sum)
  end
end
