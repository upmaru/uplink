defmodule Uplink.Clients.LXD do
  alias Uplink.Cache
  alias Uplink.Clients.Instellar

  alias Uplink.Clients.LXD

  defdelegate get_node(name),
    to: __MODULE__.Node.Manager,
    as: :show

  defdelegate list_cluster_members(),
    to: __MODULE__.Cluster.Manager,
    as: :list_members

  defdelegate list_profiles(),
    to: __MODULE__.Profile.Manager,
    as: :list

  defdelegate get_profile(name),
    to: __MODULE__.Profile.Manager,
    as: :get

  defdelegate list_instances(options \\ []),
    to: __MODULE__.Instance.Manager,
    as: :list

  defdelegate managed_network(),
    to: __MODULE__.Network.Manager,
    as: :managed

  defdelegate network_leases(project),
    to: __MODULE__.Network.Manager,
    as: :leases

  def uplink_leases do
    Cache.get({:leases, "uplink"}) || fetch_leases()
  end

  defp fetch_leases do
    config = Application.get_env(:uplink, Uplink.Data) || []
    uplink_project = Keyword.get(config, :project, "default")
    client = LXD.client()

    uplink_project =
      client
      |> Lexdee.get_project(uplink_project)
      |> case do
        {:ok, %{body: %{"name" => name}}} -> name
        {:error, %{"error_code" => 404}} -> "default"
      end

    case LXD.network_leases(uplink_project) do
      leases when is_list(leases) ->
        uplink_addresses =
          Enum.map(leases, fn lease ->
            lease.address
          end)

        Cache.put({:leases, "uplink"}, uplink_addresses, ttl: :timer.hours(3))

        uplink_addresses

      {:error, error} ->
        {:error, error}
    end
  end

  def client do
    %{
      "credential" => credential
    } = params = Instellar.get_self()

    options = Application.get_env(:uplink, :lxd)

    timeout =
      options
      |> Keyword.get(:timeout, "180")
      |> String.to_integer()

    endpoint =
      case Map.get(params, "balancer") do
        %{"address" => address, "current_state" => "active"} ->
          uri = URI.parse(credential["endpoint"])

          uri = %{uri | host: address}

          to_string(uri)

        nil ->
          credential["endpoint"]
      end

    Lexdee.create_client(
      endpoint,
      credential["certificate"],
      credential["private_key"],
      timeout: :timer.seconds(timeout)
    )
  end
end
