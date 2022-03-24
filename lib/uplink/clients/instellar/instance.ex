defmodule Uplink.Clients.Instellar.Instance do
  alias Uplink.{
    Clients,
    Cluster
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  def transition(instance, install, event_name) do
    installation_id = install.instellar_installation_id

    [
      Clients.Instellar.endpoint(),
      "installations",
      "#{installation_id}",
      "instances",
      instance,
      "events"
    ]
    |> Path.join()
    |> Req.post!({:json, %{"event" => %{"name" => event_name}}},
      headers: headers(install.deployment.hash)
    )
    |> case do
      %{status: 201, body: %{"data" => %{"attributes" => attributes}}} ->
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
