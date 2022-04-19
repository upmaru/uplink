defmodule Uplink.Clients.Instellar.Self do
  alias Uplink.{
    Cache,
    Clients,
    Cluster
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  def show(options \\ [cache: true]) do
    Cache.get(:self)
    |> case do
      nil ->
        fetch(options)

      %{"credential" => _credential} = response ->
        response
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

  defp fetch(options) do
    cache = Keyword.get(options, :cache)

    [Clients.Instellar.endpoint(), "self"]
    |> Path.join()
    |> Req.get!(headers: headers())
    |> case do
      %{status: 200, body: %{"data" => %{"attributes" => attributes}}} ->
        if cache do
          Cache.put(:self, attributes)
        end

        attributes

      %{status: _, body: body} ->
        {:error, body}
    end
  end
end
