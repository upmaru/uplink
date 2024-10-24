defimpl Uplink.Metrics.Document, for: Uplink.Metrics.Instance do
  alias Uplink.Metrics.Instance

  def memory(%Instance{data: data} = instance) do
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

  def cpu(%Instance{}, nil), do: nil

  def cpu(
        %Instance{node: node, timestamp: timestamp, data: data} = instance,
        %{
          timestamp: previous_cpu_metric_timestamp,
          data: previous_cpu_metric_data
        }
      ) do
    cores =
      Map.get(data.expanded_config, "limits.cpu") || "#{node.cpu_cores_count}"

    cores = String.to_integer(cores)

    time_diff_seconds =
      (DateTime.to_unix(timestamp, :millisecond) - previous_cpu_metric_timestamp) /
        1000

    %{"usage" => later_usage} = data.state["cpu"]

    %{"usage" => earlier_usage} = previous_cpu_metric_data

    pct = cpu_percentage(cores, time_diff_seconds, earlier_usage, later_usage)

    cpu = %{
      "system" => %{
        "cpu" => %{
          "cores" => cores,
          "system" => %{
            "pct" => 0.0
          },
          "user" => %{
            "pct" => pct
          }
        }
      }
    }

    instance
    |> build_base()
    |> Map.merge(cpu)
  end

  defp cpu_percentage(cores, time_diff_seconds, earlier_usage, later_usage) do
    available_compute = cores * time_diff_seconds * :math.pow(10, 9)

    (later_usage - earlier_usage) / available_compute * 100
  end

  defp memory_percentage(%{"total" => total, "usage" => usage_bytes}) do
    if usage_bytes > 0 and total > 0, do: usage_bytes / total, else: 0.0
  end

  defp build_base(%Instance{
         name: name,
         timestamp: timestamp,
         data: data,
         node: node
       }) do
    %{
      "@timestamp" => timestamp,
      "host" => %{
        "name" => name,
        "containerized" => data.type == "container"
      },
      "container.id" => name,
      "agent.id" => "uplink",
      "cloud" => %{
        "instance.id" => node.name
      }
    }
  end
end
