defmodule Uplink.TaskSupervisorMock do
  def async_nolink(_supervisor, fun),
    do: fun.()
end
