defprotocol Uplink.Monitors.Metric do
  @spec cpu(struct) :: {:ok, map()} | {:error, String.t()}
  def cpu(data)

  @spec memory(struct) :: {:ok, map()} | {:error, String.t()}
  def memory(data)
end
