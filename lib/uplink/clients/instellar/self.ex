defmodule Uplink.Clients.Instellar.Self do
  alias Uplink.{
    Cache,
    Clients,
    Cluster
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @backup_url "http://x/1.0/config/user.INSTELLAR_UPLINK_SELF_DATA"
  @socket "/dev/lxd/sock"

  defmodule Error do
    defexception message: "self metadata retrieval failed"
  end

  require Logger

  def show(options \\ [cache: true]) do
    Cache.get(:self)
    |> case do
      nil ->
        fetch(options)

      %{"credential" => _credential} = response ->
        response
    end
  end

  def restore do
    [Clients.Instellar.endpoint(), "self", "restore"]
    |> Path.join()
    |> Req.post!(json: %{}, headers: headers())
    |> case do
      %{status: status, body: %{"data" => %{"attributes" => attributes}}}
      when status in [201, 200] ->
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

  defp fetch(options) do
    cache = Keyword.get(options, :cache)

    [Clients.Instellar.endpoint(), "self"]
    |> Path.join()
    |> Req.get(headers: headers())
    |> case do
      {:ok, %{status: 200, body: %{"data" => %{"attributes" => attributes}}}} ->
        if cache do
          Cache.put(:self, attributes)
        end

        attributes

      {:ok, %{status: _}} ->
        fetch_from_backup!()

      {:error, _error} ->
        fetch_from_backup!()
    end
  end

  defp fetch_from_backup! do
    Logger.info("[Instellar.Self] fetching from backup...")

    with %{status: 200, body: response} <-
           Req.get!(@backup_url, unix_socket: @socket),
         %{"data" => %{"attributes" => attributes}} <-
           response
           |> Base.decode64!(body)
           |> Jason.decode!() do
      Cache.put_new(:self, attributes)

      attributes
    else
      _ -> raise Error
    end
  end
end
