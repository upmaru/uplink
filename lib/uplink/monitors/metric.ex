defprotocol Uplink.Monitors.Metric do
  @spec cpu(struct, map) :: {:ok, map()} | {:error, String.t()}
  def cpu(data, previous_cpu_metric)

  @spec memory(struct) :: {:ok, map()} | {:error, String.t()}
  def memory(data)
end
