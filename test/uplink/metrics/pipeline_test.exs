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
             uptime: uptime,
             network: network,
             load: load
           } = data

    assert is_nil(cpu)
    assert is_nil(load)
    assert is_nil(network)

    assert %{"system" => %{"memory" => _}} = memory
    assert %{"system" => %{"filesystem" => _}} = filesystem
    assert %{"system" => %{"diskio" => _}} = diskio
    assert %{"system" => %{"uptime" => _}} = uptime
  end

  test "handle message with cpu metric", %{
    message_with_previous_cpu_metric: message
  } do
    ref = Broadway.test_message(Uplink.Metrics.Pipeline, message)

    assert_receive {:ack, ^ref, [%{data: data}], []}, 10_000

    assert %{cpu: cpu} = data

    assert %{"system" => %{"cpu" => _}} = cpu
  end

  test "handle message with network metric", %{
    message_with_previous_network_metric: message
  } do
    ref = Broadway.test_message(Uplink.Metrics.Pipeline, message)

    assert_receive {:ack, ^ref, [%{data: data}], []}

    assert %{network: network} = data

    assert [
             %{"system" => %{"network" => _}},
             %{"system" => %{"network" => _}},
             %{"system" => %{"network" => _}}
           ] = network
  end

  test "handle message with load 1", %{
    message_with_cpu_60_metric: message
  } do
    ref = Broadway.test_message(Uplink.Metrics.Pipeline, message)

    assert_receive {:ack, ^ref, [%{data: data}], []}, 10_000

    assert %{load: load} = data

    assert %{"system" => %{"load" => _}} = load
  end

  test "handle message with load 5", %{
    message_with_cpu_300_metric: message
  } do
    ref = Broadway.test_message(Uplink.Metrics.Pipeline, message)

    assert_receive {:ack, ^ref, [%{data: data}], []}

    assert %{load: load} = data

    assert %{"system" => %{"load" => %{"1" => _, "5" => load_5}}} = load

    assert not is_nil(load_5)
  end

  test "handle message with load 15", %{
    message_with_cpu_900_metric: message
  } do
    ref = Broadway.test_message(Uplink.Metrics.Pipeline, message)

    assert_receive {:ack, ^ref, [%{data: data}], []}, 10_000

    assert %{load: load} = data

    assert %{"system" => %{"load" => %{"1" => _, "5" => _, "15" => load_15}}} =
             load

    assert not is_nil(load_15)
  end

  test "handle batch", %{
    message_with_previous_cpu_metric: message1,
    message_with_previous_network_metric: message2
  } do
    ref = Broadway.test_batch(Uplink.Metrics.Pipeline, [message1, message2])

    assert_receive {:ack, ^ref, successful, failed}, 10_000

    assert length(successful) == 2
    assert length(failed) == 0
  end
end
