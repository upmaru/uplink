defmodule Uplink.Clients.Instellar.Installation do
  alias Uplink.{
    Cluster,
    Packages
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @endpoint "https://web.instellar.app"

  def metadata(%Deployment{hash: hash, installation: installation}) do
    %{instellar_installation_id: instellar_installation_id} = installation

    signature = compute_signature(hash)

    @endpoint
    |> Path.join(["installations", instellar_installation_id])
    |> Req.get!(headers: headers(hash))
    |> case do
    end
  end

  defp headers(hash) do
    [
      {"x-uplink-deployment-hash", hash},
      {"x-uplink-signature-256", "sha256=#{compute_signature(hash)}"},
      {"x-uplink-installation-id", Cluster.get(:installation_id)}
    ]
  end
end
