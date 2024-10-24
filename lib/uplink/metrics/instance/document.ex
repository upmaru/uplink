defimpl Uplink.Metrics.Document, for: Uplink.Metrics.Instance do
  alias Uplink.Metrics.Instance

  def memory(%Instance{data: data, metrics: metrics} = instance) do
    %{
      "memory" =>
        %{"usage" => memory_usage, "total" => memory_total} = memory_data
    } = data.state

    pct = memory_percentage(memory_data)

    cached_memory =
      Enum.find(metrics, fn metric ->
        metric.label == "lxd_memory_Cached_bytes"
      end)

    actual_used_bytes = actual_memory_usage(cached_memory, memory_usage)

    actual_used_pct =
      memory_percentage(%{"usage" => actual_used_bytes, "total" => memory_total})

    memory_params = %{
      "system" => %{
        "memory" => %{
          "free" => memory_total - memory_usage,
          "actual" => %{
            "used" => %{
              "bytes" => actual_used_bytes,
              "pct" => actual_used_pct
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

  def diskio(%Instance{metrics: metrics} = instance) do
    disk_read_bytes = sum_metrics(metrics, "lxd_disk_read_bytes_total")
    disk_read_count = sum_metrics(metrics, "lxd_disk_reads_completed_total")
    disk_write_bytes = sum_metrics(metrics, "lxd_disk_written_bytes_total")
    disk_write_count = sum_metrics(metrics, "lxd_disk_writes_completed_total")

    diskio_params = %{
      "system" => %{
        "diskio" => %{
          "read" => %{
            "bytes" => disk_read_bytes,
            "count" => disk_read_count
          },
          "write" => %{
            "bytes" => disk_write_bytes,
            "count" => disk_write_count
          }
        }
      }
    }

    instance
    |> build_base()
    |> Map.merge(diskio_params)
  end

  def uptime(%Instance{data: %{state: %{"status" => "Running"}}} = instance) do
    now = DateTime.to_unix(instance.timestamp, :millisecond)
    last_used_at = DateTime.to_unix(instance.data.last_used_at, :millisecond)

    duration_ms = now - last_used_at

    uptime_params = %{
      "system" => %{
        "uptime" => %{"duration" => %{"ms" => duration_ms}}
      }
    }

    instance
    |> build_base()
    |> Map.merge(uptime_params)
  end

  def uptime(%Instance{}), do: nil

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

    cpu_params = %{
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
    |> Map.merge(cpu_params)
  end

  def filesystem(%Instance{data: data, node: node} = instance) do
    %{"disk" => %{"root" => %{"usage" => usage_bytes, "total" => total_bytes}}} =
      data.state

    total_bytes = if total_bytes > 0, do: total_bytes, else: node.total_storage

    pct = usage_bytes / total_bytes

    filesystem_params = %{
      "system" => %{
        "filesystem" => %{
          "device_name" => "root",
          "mount_point" => "/",
          "total" => total_bytes,
          "used" => %{
            "bytes" => usage_bytes,
            "pct" => pct
          }
        }
      }
    }

    instance
    |> build_base()
    |> Map.merge(filesystem_params)
  end

  defp cpu_percentage(cores, time_diff_seconds, earlier_usage, later_usage) do
    available_compute = cores * time_diff_seconds * :math.pow(10, 9)

    (later_usage - earlier_usage) / available_compute * 100
  end

  defp memory_percentage(%{"total" => total, "usage" => usage_bytes}) do
    if usage_bytes > 0 and total > 0, do: usage_bytes / total, else: 0.0
  end

  defp actual_memory_usage(
         %PrometheusParser.Line{value: cached_memory_value},
         memory_usage
       ) do
    Decimal.new(memory_usage)
    |> Decimal.sub(Decimal.new(cached_memory_value))
    |> Decimal.to_integer()
  end

  defp actual_memory_usage(nil, _), do: 0

  defp sum_metrics(metrics, key) when is_list(metrics) do
    metrics
    |> Enum.filter(&(&1.label == key))
    |> Enum.map(& &1.value)
    |> Enum.map(&Decimal.new/1)
    |> Enum.map(&Decimal.to_integer/1)
    |> Enum.sum()
  end

  defp sum_metrics(nil, _key), do: 0

  defp build_base(%Instance{
         account: account,
         name: name,
         timestamp: timestamp,
         data: data,
         node: node
       }) do
    config = data.expanded_config
    os = Map.get(config, "image.os")
    release = Map.get(config, "image.release")
    serial = Map.get(config, "image.serial")

    %{
      "@timestamp" => timestamp,
      "host" => %{
        "name" => name,
        "created" => data.created_at,
        "accessed" => data.last_used_at,
        "containerized" => data.type == "container",
        "os" => %{
          "codename" => os,
          "build" => "#{release}-#{serial}"
        }
      },
      "container.id" => name,
      "agent.id" => "uplink",
      "cloud" => %{
        "account.id" => account.id,
        "instance.id" => node.name
      }
    }
  end
end
