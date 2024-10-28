defprotocol Uplink.Metrics.Document do
  @spec uptime(struct) :: map() | nil
  def uptime(data)

  @spec filesystem(struct) :: map() | nil
  def filesystem(data)

  @spec cpu(struct, map | nil) :: map() | nil
  def cpu(data, previous_cpu_metric)

  @spec memory(struct) :: map() | nil
  def memory(data)

  @spec diskio(struct) :: map() | nil
  def diskio(data)

  @spec network(struct, map | nil) :: map() | nil
  def network(data, previous_network_metric)

  @spec load(struct, map | nil) :: map() | nil
  def load(data, previous_load_metric)
end
