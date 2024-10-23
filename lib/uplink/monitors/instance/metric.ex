defimpl Uplink.Monitors.Metric, for: Uplink.Monitors.Instance do
  alias Uplink.Monitors.Instance

  def memory(
        %Instance{name: node_name, timestamp: timestamp, data: data} = instance
      ) do
    %{
      "memory" =>
        %{"usage" => memory_usage, "total" => memory_total} = memory_data
    } = data.state

    pct = memory_percentage(memory_data)

    memory_params = %{
      "system" => %{
        "memory" => %{
          "actual" => %{
            "used" => %{
              "bytes" => memory_usage,
              "pct" => pct
            }
          },
          "total" => memory_total,
          "used" => %{
            "bytes" => memory_usage,
            "pct" => pct
          }
        }
      }
    }

    instance
    |> build_base()
    |> Map.merge(memory_params)
  end

  def cpu(%Instance{} = instance, nil), do: nil

  def cpu(
        %Instance{name: node_name, timestamp: timestamp, node: node, data: data} =
          instance,
        %{
          timestamp: previous_cpu_metric_timestamp,
          data: previous_cpu_metric_data
        }
      ) do
    cores =
      Map.get(data.expanded_config, "limits.cpu") || "#{node.cpu_cores_count}"

    cpu = %{
      "system" => %{
        "cpu" => %{
          "cores" => String.to_integer(cores)
        }
      }
    }

    instance
    |> build_base()
    |> Map.merge(cpu)
  end

  defp cpu_percentage(cores, time_diff) do
    available_compute = cores * time_diff * :math.pow(10, 9)
  end

  defp memory_percentage(%{"total" => total, "usage" => usage_bytes}) do
    if usage_bytes > 0 and total > 0, do: usage_bytes / total, else: 0.0
  end

  defp build_base(%Instance{name: node_name, timestamp: timestamp, data: data}) do
    %{
      "@timestamp" => timestamp,
      "host" => %{
        "name" => node_name,
        "containerized" => data.type == "container"
      },
      "container.id" => node_name
    }
  end
end
