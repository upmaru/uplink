defmodule Uplink.Clients.LXD do
  alias Uplink.Clients.Instellar

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
