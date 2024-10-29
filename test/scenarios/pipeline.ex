defmodule Uplink.Scenarios.Pipeline do
  alias Uplink.Cache

  @network_metric %{
    "eth0" => %{
      "addresses" => [
        %{
          "address" => "10.89.212.187",
          "family" => "inet",
          "netmask" => "24",
          "scope" => "global"
        },
        %{
          "address" => "fd42:bcd9:8738:4f0b:216:3eff:fe49:974b",
          "family" => "inet6",
          "netmask" => "64",
          "scope" => "global"
        },
        %{
          "address" => "fe80::216:3eff:fe49:974b",
          "family" => "inet6",
          "netmask" => "64",
          "scope" => "link"
        }
      ],
      "counters" => %{
        "bytes_received" => 536_178_767,
        "bytes_sent" => 598_876_792,
        "errors_received" => 0,
        "errors_sent" => 0,
        "packets_dropped_inbound" => 0,
        "packets_dropped_outbound" => 0,
        "packets_received" => 3_861_861,
        "packets_sent" => 5_494_401
      },
      "host_name" => "veth7baf4590",
      "hwaddr" => "00:16:3e:49:97:4b",
      "mtu" => 1500,
      "state" => "up",
      "type" => "broadcast"
    },
    "lo" => %{
      "addresses" => [
        %{
          "address" => "127.0.0.1",
          "family" => "inet",
          "netmask" => "8",
          "scope" => "local"
        },
        %{
          "address" => "::1",
          "family" => "inet6",
          "netmask" => "128",
          "scope" => "local"
        }
      ],
      "counters" => %{
        "bytes_received" => 5_145_976,
        "bytes_sent" => 5_145_976,
        "errors_received" => 0,
        "errors_sent" => 0,
        "packets_dropped_inbound" => 0,
        "packets_dropped_outbound" => 0,
        "packets_received" => 102_914,
        "packets_sent" => 102_914
      },
      "host_name" => "",
      "hwaddr" => "",
      "mtu" => 65536,
      "state" => "up",
      "type" => "loopback"
    },
    "tailscale0" => %{
      "addresses" => [
        %{
          "address" => "100.100.201.17",
          "family" => "inet",
          "netmask" => "32",
          "scope" => "global"
        },
        %{
          "address" => "fd7a:115c:a1e0::6501:c911",
          "family" => "inet6",
          "netmask" => "128",
          "scope" => "global"
        },
        %{
          "address" => "fe80::cf0d:6cf3:a4c3:23a4",
          "family" => "inet6",
          "netmask" => "64",
          "scope" => "link"
        }
      ],
      "counters" => %{
        "bytes_received" => 63_039_392,
        "bytes_sent" => 83_946_128,
        "errors_received" => 0,
        "errors_sent" => 0,
        "packets_dropped_inbound" => 0,
        "packets_dropped_outbound" => 0,
        "packets_received" => 603_885,
        "packets_sent" => 766_923
      },
      "host_name" => "",
      "hwaddr" => "",
      "mtu" => 1280,
      "state" => "up",
      "type" => "point-to-point"
    }
  }

  @instance_metric %Uplink.Metrics.Instance{
    name: "insterra-testing",
    timestamp: ~U[2024-10-25 09:44:50.138459Z],
    data: %Uplink.Clients.LXD.Instance{
      name: "insterra-testing",
      type: "container",
      location: "arrakis",
      status: "Running",
      architecture: "x86_64",
      profiles: ["default"],
      project: "testing",
      description: nil,
      created_at: ~U[2024-10-04 06:48:24.543615Z],
      last_used_at: ~U[2024-10-05 22:37:55.312007Z],
      expanded_config: %{
        "image.architecture" => "amd64",
        "image.description" => "alpine 3.19 amd64 (20240708-44)",
        "image.os" => "alpine",
        "image.release" => "3.19",
        "image.requirements.secureboot" => "false",
        "image.serial" => "20240708-44",
        "image.type" => "squashfs",
        "image.variant" => "default",
        "volatile.base_image" =>
          "8279423f529b339b6ebd619e8a69001bd277cd2bd30fc641dbc74516d09c51fc",
        "volatile.cloud-init.instance-id" =>
          "594f1088-f3ff-401b-981a-aef7fd9470c2",
        "volatile.eth0.host_name" => "veth7baf4590",
        "volatile.eth0.hwaddr" => "00:16:3e:49:97:4b",
        "volatile.idmap.base" => "0",
        "volatile.idmap.current" =>
          "[{\"Isuid\":true,\"Isgid\":false,\"Hostid\":1000000,\"Nsid\":0,\"Maprange\":1000000000},{\"Isuid\":false,\"Isgid\":true,\"Hostid\":1000000,\"Nsid\":0,\"Maprange\":1000000000}]",
        "volatile.idmap.next" =>
          "[{\"Isuid\":true,\"Isgid\":false,\"Hostid\":1000000,\"Nsid\":0,\"Maprange\":1000000000},{\"Isuid\":false,\"Isgid\":true,\"Hostid\":1000000,\"Nsid\":0,\"Maprange\":1000000000}]",
        "volatile.last_state.idmap" => "[]",
        "volatile.last_state.power" => "RUNNING",
        "volatile.uuid" => "e1a4139a-ffbf-4099-b652-37ef8ea441ee",
        "volatile.uuid.generation" => "e1a4139a-ffbf-4099-b652-37ef8ea441ee"
      },
      expanded_devices: %{
        "eth0" => %{
          "name" => "eth0",
          "network" => "lxdbr0",
          "type" => "nic"
        },
        "root" => %{"path" => "/", "pool" => "default", "type" => "disk"}
      },
      state: %{
        "cpu" => %{"usage" => 33_909_892_118_000},
        "disk" => %{"root" => %{"total" => 0, "usage" => 432_270_464}},
        "memory" => %{
          "swap_usage" => 0,
          "swap_usage_peak" => 0,
          "total" => 65_747_700_000,
          "usage" => 115_965_952,
          "usage_peak" => 0
        },
        "network" => @network_metric,
        "pid" => 3219,
        "processes" => 33,
        "status" => "Running",
        "status_code" => 103
      }
    },
    node: %Uplink.Clients.LXD.Node{
      name: "arrakis",
      cpu_cores_count: 36,
      total_memory: 68_719_476_736,
      total_storage: 24_504_830_042_112
    },
    metrics: [
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sdd"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "2.7889664e+07",
        documentation: nil,
        type: nil,
        label: "lxd_disk_read_bytes_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sdf"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "2.8053504e+07",
        documentation: nil,
        type: nil,
        label: "lxd_disk_read_bytes_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sde"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "3.1424512e+07",
        documentation: nil,
        type: nil,
        label: "lxd_disk_read_bytes_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sdb"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "2.7951104e+07",
        documentation: nil,
        type: nil,
        label: "lxd_disk_read_bytes_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sdc"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "3.1215616e+07",
        documentation: nil,
        type: nil,
        label: "lxd_disk_read_bytes_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sda"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "3.1203328e+07",
        documentation: nil,
        type: nil,
        label: "lxd_disk_read_bytes_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sdd"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "2769",
        documentation: nil,
        type: nil,
        label: "lxd_disk_reads_completed_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sdf"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "2818",
        documentation: nil,
        type: nil,
        label: "lxd_disk_reads_completed_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sde"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "3204",
        documentation: nil,
        type: nil,
        label: "lxd_disk_reads_completed_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sdb"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "2821",
        documentation: nil,
        type: nil,
        label: "lxd_disk_reads_completed_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sdc"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "3244",
        documentation: nil,
        type: nil,
        label: "lxd_disk_reads_completed_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"device", "sda"},
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "3215",
        documentation: nil,
        type: nil,
        label: "lxd_disk_reads_completed_total"
      },
      %PrometheusParser.Line{
        line_type: "ENTRY",
        timestamp: nil,
        pairs: [
          {"name", "insterra-testing"},
          {"project", "testing"},
          {"type", "container"}
        ],
        value: "7.8544896e+07",
        documentation: nil,
        type: nil,
        label: "lxd_memory_Cached_bytes"
      }
    ],
    account: %{id: "upmaru-stage"}
  }

  def self(_context) do
    Cache.put(:self, %{
      "credential" => %{
        "endpoint" => "http://localhost"
      },
      "uplink" => %{
        "id" => 1,
        "image_server" => "https://localhost/spaces/test"
      },
      "organization" => %{
        "slug" => "someorg",
        "storage" => %{
          "type" => "s3",
          "host" => "some.host",
          "bucket" => "some-bucket",
          "region" => "sgp1",
          "credential" => %{
            "access_key_id" => "access-key",
            "secret_access_key" => "secret"
          }
        }
      },
      "instances" => [
        %{
          "id" => 1,
          "slug" => "uplink-01",
          "node" => %{
            "id" => 1,
            "slug" => "some-node-01",
            "public_ip" => "127.0.0.1"
          }
        }
      ]
    })

    :ok
  end

  def messages(_context) do
    message_without_previous_cpu_metric = %{
      metric: @instance_metric,
      previous_cpu_metric: nil,
      previous_network_metric: nil,
      cpu_60_metric: nil,
      cpu_300_metric: nil,
      cpu_900_metric: nil
    }

    message_with_previous_cpu_metric = %{
      metric: @instance_metric,
      previous_cpu_metric: %{
        data: %{"usage" => 1},
        timestamp: 1
      },
      previous_network_metric: nil,
      cpu_60_metric: nil,
      cpu_300_metric: nil,
      cpu_900_metric: nil
    }

    message_with_previous_network_metric = %{
      metric: @instance_metric,
      previous_cpu_metric: nil,
      previous_network_metric: %{
        timestamp: 1,
        data: @network_metric
      },
      cpu_60_metric: nil,
      cpu_300_metric: nil,
      cpu_900_metric: nil
    }

    message_with_cpu_60_metric = %{
      metric: @instance_metric,
      previous_cpu_metric: nil,
      previous_network_metric: nil,
      cpu_60_metric: %{
        data: %{"usage" => 1_000_000},
        timestamp: 1
      },
      cpu_300_metric: nil,
      cpu_900_metric: nil
    }

    message_with_cpu_300_metric = %{
      metric: @instance_metric,
      previous_cpu_metric: nil,
      previous_network_metric: nil,
      cpu_60_metric: %{
        data: %{"usage" => 1_000_000},
        timestamp: 1
      },
      cpu_300_metric: %{
        data: %{"usage" => 1_000_000},
        timestamp: 1
      },
      cpu_900_metric: nil
    }

    message_with_cpu_900_metric = %{
      metric: @instance_metric,
      previous_cpu_metric: nil,
      previous_network_metric: nil,
      cpu_60_metric: %{
        data: %{"usage" => 1_000_000},
        timestamp: 1
      },
      cpu_300_metric: %{
        data: %{"usage" => 1_000_000},
        timestamp: 1
      },
      cpu_900_metric: %{
        data: %{"usage" => 1_000_000},
        timestamp: 1
      }
    }

    {:ok,
     message_without_previous_cpu_metric: message_without_previous_cpu_metric,
     message_with_previous_cpu_metric: message_with_previous_cpu_metric,
     message_with_previous_network_metric: message_with_previous_network_metric,
     message_with_cpu_60_metric: message_with_cpu_60_metric,
     message_with_cpu_300_metric: message_with_cpu_300_metric,
     message_with_cpu_900_metric: message_with_cpu_900_metric}
  end
end
