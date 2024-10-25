defmodule Uplink.Metrics.PipelineTest do
  use ExUnit.Case

  import Uplink.Scenarios.Pipeline
  import TimeHelper

  alias Uplink.Cache
  alias Uplink.Pipelines

  setup [:self, :messages]

  setup do
    Cache.put_new({:monitors, :metrics}, [])

    Pipelines.start(Uplink.Metrics.Pipeline)

    wait_until(5_000, fn ->
      assert Uplink.Pipelines.list() != []
    end)

    :ok
  end

  test "handle message without previous cpu metric", %{
    message_without_previous_cpu_metric: message
  } do
    ref = Broadway.test_message(Uplink.Metrics.Pipeline, message)

    assert_receive {:ack, ^ref, [%{data: data}], []}

    assert %{
             memory: memory,
             filesystem: filesystem,
             cpu: cpu,
             diskio: diskio,
             uptime: uptime
           } = data

    assert is_nil(cpu)

    assert %{"system" => %{"memory" => _}} = memory
    assert %{"system" => %{"filesystem" => _}} = filesystem
    assert %{"system" => %{"diskio" => _}} = diskio
    assert %{"system" => %{"uptime" => _}} = uptime
  end
end
