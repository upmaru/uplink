defmodule Uplink.Clients.Instellar.Self do
  alias Uplink.{
    Clients,
    Cluster
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  def show do
    [Clients.Instellar.endpoint(), "self"]
    |> Path.join()
    |> Req.get!(headers: headers())
    |> case do
      %{status: 200, body: %{"data" => %{"attributes" => attributes}}} ->
        {:ok, attributes}

      %{status: _, body: body} ->
        {:error, body}
    end
  end

  def headers do
    secret = Uplink.Secret.get()
    otp = :pot.totp(String.slice(secret, 0..15))

    [
      {"x-uplink-signature-256", "sha256=#{compute_signature(otp)}"},
      {"x-uplink-installation-id", Cluster.get(:installation_id)}
    ]
  end
end
