defmodule Uplink.Clustering.LXD do
  use GenServer
  use Cluster.Strategy

  alias Cluster.Strategy.State
  alias Uplink.Clients

  @default_polling_interval 5_000

  def start_link(args), do: GenServer.start_link(__MODULE__, args)

  @impl true
  def init([%State{meta: nil} = state]) do
    init([%State{state | :meta => MapSet.new()}])
  end

  def init([%State{} = state]) do
    {:ok, load(state)}
  end

  @impl true
  def handle_info(:timeout, state) do
    handle_info(:load, state)
  end

  def handle_info(:load, state) do
    {:noreply, load(state)}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp load(
         %State{
           topology: topology,
           connect: connect,
           disconnect: disconnect,
           list_nodes: list_nodes
         } = state
       ) do
    case get_nodes(state) do
      {:ok, new_nodes} ->
        removed = MapSet.difference(state.meta, new_nodes)

        new_nodes =
          disconnect_nodes(
            topology,
            disconnect,
            list_nodes,
            MapSet.to_list(removed),
            new_nodes
          )

        new_nodes =
          connect_nodes(
            topology,
            connect,
            list_nodes,
            MapSet.to_list(new_nodes),
            new_nodes
          )

        Process.send_after(
          self(),
          :load,
          Keyword.get(
            state.config,
            :polling_interval,
            @default_polling_interval
          )
        )

        %State{state | :meta => new_nodes}

      _ ->
        Process.send_after(
          self(),
          :load,
          Keyword.get(
            state.config,
            :polling_interval,
            @default_polling_interval
          )
        )

        state
    end
  end

  defp get_nodes(%State{config: config}) do
    installation_id = Uplink.Cluster.get(:installation_id)

    app_name = Keyword.get(config, :app_name, "uplink")

    profile_name =
      Keyword.get(config, :lxd_profile_name, "uplink-#{installation_id}")

    Clients.LXD.get_profile(profile_name)
    |> case do
      {:ok, profile} ->
        nodes =
          profile.used_by
          |> Enum.map(fn node ->
            "/1.0/instances/" <> node_name = node

            node_name =
              case String.split(node_name, "?") do
                [node_name, _] -> node_name
                [node_name] -> node_name
              end

            :"#{app_name}@#{node_name}"
          end)

        {:ok, MapSet.new(nodes)}

      _ ->
        {:error, []}
    end
  end

  defp disconnect_nodes(
         topology,
         disconnect,
         list_nodes,
         to_be_removed,
         new_nodes
       ) do
    case Cluster.Strategy.disconnect_nodes(
           topology,
           disconnect,
           list_nodes,
           to_be_removed
         ) do
      :ok ->
        new_nodes

      {:error, bad_nodes} ->
        Enum.reduce(bad_nodes, new_nodes, fn {n, _}, acc ->
          MapSet.put(acc, n)
        end)
    end
  end

  def connect_nodes(topology, connect, list_nodes, to_be_connected, new_nodes) do
    case Cluster.Strategy.connect_nodes(
           topology,
           connect,
           list_nodes,
           to_be_connected
         ) do
      :ok ->
        new_nodes

      {:error, bad_nodes} ->
        Enum.reduce(bad_nodes, new_nodes, fn {n, _}, acc ->
          MapSet.delete(acc, n)
        end)
    end
  end
end
