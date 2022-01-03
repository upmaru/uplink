defmodule Uplink.Clients.Instellar.Installation do
  alias Uplink.{
    Clients,
    Cluster,
    Packages
  }

  alias Packages.Deployment

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  def metadata(%Deployment{hash: hash, installation: installation}) do
    %{instellar_installation_id: instellar_installation_id} = installation

    [
      Clients.Instellar.endpoint(),
      "installations",
      "#{instellar_installation_id}"
    ]
    |> Path.join()
    |> Req.get!(headers: headers(hash))
    |> case do
      %{status: 200, body: %{"data" => %{"attributes" => attributes}}} ->
        {:ok, attributes}

      %{status: _, body: body} ->
        {:error, body}
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
