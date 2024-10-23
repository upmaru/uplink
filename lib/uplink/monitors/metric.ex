defprotocol Uplink.Monitors.Metric do
  @spec cpu(struct, map) :: map() | nil
  def cpu(data, previous_cpu_metric)

  @spec memory(struct) :: map() | nil
  def memory(data)
end
