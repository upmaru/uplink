defprotocol Uplink.Metrics.Document do
  @spec uptime(struct) :: map() | nil
  def uptime(data)

  @spec filesystem(struct) :: map() | nil
  def filesystem(data)

  @spec cpu(struct, map) :: map() | nil
  def cpu(data, previous_cpu_metric)

  @spec memory(struct) :: map() | nil
  def memory(data)

  @spec diskio(struct) :: map() | nil
  def diskio(data)
end
