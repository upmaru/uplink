Mox.defmock(Uplink.Drivers.Bucket.AwsMock, for: Uplink.Drivers.Behaviour)
Mox.defmock(Uplink.Release.TasksMock, for: Uplink.Release.Tasks)

defmodule Uplink.TaskSupervisorMock do
  def async_nolink(_supervisor, fun, _options \\ []),
    do: fun.()
end
