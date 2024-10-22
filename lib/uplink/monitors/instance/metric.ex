defimpl Uplink.Monitors.Metric, for: Uplink.Monitors.Instance do
  alias Uplink.Monitors.Instance

  def memory(%Instance{name: node_name, data: data}) do
    %{
      "@timestamp" => DateTime.utc_now(),
      "host" => %{
        "name" => node_name,
        "containerized" => false
      }
    }
  end
end
