defimpl Uplink.Monitors.Metric, for: Uplink.Monitors.Instance do
  alias Uplink.Monitors.Instance

  def memory(%Instance{name: node_name, timestamp: timestamp, data: data}) do
    %{
      "memory" =>
        %{"usage" => memory_usage, "total" => memory_total} = memory_data
    } = data.state

    pct = percentage(memory_data)

    %{
      "@timestamp" => timestamp,
      "host" => %{
        "name" => node_name,
        "containerized" => data.type == "container"
      },
      "container.id" => node_name,
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
  end

  def cpu(%Instance{} = instance, nil), do: nil

  def cpu(
        %Instance{name: node_name, timestamp: timestamp, data: data} = instance,
        %{
          timestamp: previous_cpu_metric_timestamp,
          data: previous_cpu_metric_data
        }
      ) do
    %{
      "@timestamp" => timestamp,
      "host" => %{
        "name" => node_name,
        "containerized" => data.type == "container"
      },
      "container.id" => node_name,
      "system" => %{
        "cpu" => %{
          "cores" => 1
        }
      }
    }
  end

  defp percentage(%{"total" => total, "usage" => usage_bytes}) do
    if usage_bytes > 0 and total > 0, do: usage_bytes / total, else: 0.0
  end
end
