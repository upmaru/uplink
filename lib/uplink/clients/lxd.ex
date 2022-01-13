defmodule Uplink.Clients.LXD do
  alias Uplink.Clients.Instellar
  
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
