defmodule Uplink.Availability do
  alias Uplink.Metrics
  alias Uplink.Pipelines

  alias Uplink.Clients.LXD
  alias Uplink.Clients.Instellar

  alias __MODULE__.Query

  def check! do
    case get_monitor() do
      %{"attributes" => _attributes} = monitor ->
        check(monitor)

      {:ok, monitors} ->
        monitors
        |> List.first()
        |> check()

      _ ->
        raise "No monitor found"
    end
  end

  def check(%{"attributes" => _} = monitor) when is_map(monitor) do
    indices =
      Query.index_types()
      |> Enum.map(&Metrics.index/1)

    members = LXD.list_cluster_members()

    query = Query.build(members, indices)

    Metrics.query!(monitor, query)
  end

  defp get_monitor do
    monitors = Pipelines.get_monitors(:metrics)

    if monitors == [] do
      Instellar.list_monitors()
    else
      List.first(monitors)
    end
  end
end
