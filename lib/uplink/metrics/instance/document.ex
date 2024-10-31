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

  def network(%Instance{}, nil), do: nil

  def network(%Instance{data: %{state: %{"network" => nil}}}, _), do: nil

  def network(
        %Instance{
          timestamp: timestamp,
          data: %{name: name, state: %{"network" => network}} = data
        } = instance,
        %{
          timestamp: previous_network_metric_timestamp,
          data: previous_network_metric_data
        }
      )
      when is_map(network) do
    config = data.expanded_config
    os = Map.get(config, "image.os")
    release = Map.get(config, "image.release")
    serial = Map.get(config, "image.serial")

    time_diff_milliseconds =
      DateTime.to_unix(timestamp, :millisecond) -
        previous_network_metric_timestamp

    Enum.map(network, fn {interface, network_data} ->
      {_, previous_network_data} =
        Enum.find(previous_network_metric_data, fn {i, _} -> i == interface end)

      %{"counters" => current_counters} = network_data

      %{"counters" => previous_counters} = previous_network_data

      %{
        "bytes_received" => previous_bytes_received,
        "bytes_sent" => previous_bytes_sent,
        "packets_received" => previous_packets_received,
        "packets_sent" => previous_packets_sent
      } = previous_counters

      %{
        "bytes_received" => bytes_received,
        "bytes_sent" => bytes_sent,
        "errors_received" => errors_received,
        "errors_sent" => errors_sent,
        "packets_dropped_inbound" => packets_dropped_inbound,
        "packets_dropped_outbound" => packets_dropped_outbound,
        "packets_received" => packets_received,
        "packets_sent" => packets_sent
      } = current_counters

      diff_bytes_received = bytes_received - previous_bytes_received
      diff_packets_received = packets_received - previous_packets_received
      diff_bytes_sent = bytes_sent - previous_bytes_sent
      diff_packets_sent = packets_sent - previous_packets_sent

      network_params = %{
        "metricset" => %{
          "period" => time_diff_milliseconds
        },
        "host" => %{
          "name" => name,
          "created" => data.created_at,
          "accessed" => data.last_used_at,
          "containerized" => data.type == "container",
          "os" => %{
            "codename" => os,
            "build" => "#{release}-#{serial}"
          },
          "network" => %{
            "in" => %{
              "bytes" => diff_bytes_received,
              "packets" => diff_packets_received
            },
            "ingress" => %{
              "bytes" => diff_bytes_received,
              "packets" => diff_packets_received
            },
            "out" => %{
              "bytes" => diff_bytes_sent,
              "packets" => diff_packets_sent
            },
            "egress" => %{
              "bytes" => diff_bytes_sent,
              "packets" => diff_packets_sent
            }
          }
        },
        "system" => %{
          "network" => %{
            "in" => %{
              "bytes" => diff_bytes_received,
              "dropped" => packets_dropped_inbound,
              "errors" => errors_received,
              "packets" => diff_packets_received
            },
            "name" => interface,
            "out" => %{
              "bytes" => diff_bytes_received,
              "dropped" => packets_dropped_outbound,
              "errors" => errors_sent,
              "packets" => diff_packets_sent
            }
          }
        }
      }

      instance
      |> build_base()
      |> Map.merge(network_params)
    end)
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

  def load(%Instance{}, %{cpu_60_metric: nil}), do: nil

  def load(
        %Instance{data: data, timestamp: timestamp, node: node} = instance,
        %{cpu_60_metric: cpu_60_metric} = params
      ) do
    cores =
      Map.get(data.expanded_config, "limits.cpu") || "#{node.cpu_cores_count}"

    cores = String.to_integer(cores)

    %{data: %{"usage" => load_1_usage}} = cpu_60_metric
    %{"usage" => current_usage} = data.state["cpu"]

    load_1_time_diff_seconds =
      (DateTime.to_unix(timestamp, :millisecond) - cpu_60_metric.timestamp) /
        1000

    load_1 =
      cpu_percentage(
        cores,
        load_1_time_diff_seconds,
        load_1_usage,
        current_usage
      )

    load_1 = %{load: load_1 * cores, norm: load_1}

    load_5 =
      if cpu_300_metric = Map.get(params, :cpu_300_metric) do
        %{data: %{"usage" => load_5_usage}} = cpu_300_metric

        load_5_time_diff_seconds =
          (DateTime.to_unix(timestamp, :millisecond) - cpu_300_metric.timestamp) /
            1000

        load_5 =
          cpu_percentage(
            cores,
            load_5_time_diff_seconds,
            load_5_usage,
            current_usage
          )

        %{load: load_5 * cores, norm: load_5}
      else
        %{}
      end

    load_15 =
      if cpu_900_metric = Map.get(params, :cpu_900_metric) do
        %{data: %{"usage" => load_15_usage}} = cpu_900_metric

        load_15_time_diff_seconds =
          (DateTime.to_unix(timestamp, :millisecond) - cpu_900_metric.timestamp) /
            1000

        load_15 =
          cpu_percentage(
            cores,
            load_15_time_diff_seconds,
            load_15_usage,
            current_usage
          )

        %{load: load_15 * cores, norm: load_15}
      else
        %{}
      end

    load_params = %{
      "system" => %{
        "load" => %{
          "cores" => cores,
          "1" => load_1.load,
          "5" => Map.get(load_5, :load),
          "15" => Map.get(load_15, :load),
          "norm" => %{
            "1" => load_1.norm,
            "5" => Map.get(load_5, :norm),
            "15" => Map.get(load_15, :norm)
          }
        }
      }
    }

    instance
    |> build_base()
    |> Map.merge(load_params)
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

    (later_usage - earlier_usage) / available_compute
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
