Mox.defmock(Uplink.Drivers.Bucket.AwsMock, for: Uplink.Drivers.Behaviour)

defmodule Uplink.TaskSupervisorMock do
  def async_nolink(_supervisor, fun),
    do: fun.()
end
