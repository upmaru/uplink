defmodule Uplink.Clients.LXD do
  alias Uplink.Clients.Instellar

  defdelegate list_profiles(),
    to: __MODULE__.Profile.Manager,
    as: :list

  defdelegate list_instances(),
    to: __MODULE__.Instance.Manager,
    as: :list

  defdelegate managed_network(),
    to: __MODULE__.Network.Manager,
    as: :managed

  defdelegate network_leases(),
    to: __MODULE__.Network.Manager,
    as: :leases

  def client do
    %{
      "credential" => credential
    } = Instellar.get_self()

    Lexdee.create_client(
      credential["endpoint"],
      credential["certificate"],
      credential["private_key"]
    )
  end
end
