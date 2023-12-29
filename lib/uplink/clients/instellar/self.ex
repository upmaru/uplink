defmodule Uplink.Clients.Instellar.Self do
  alias Uplink.{
    Cache,
    Clients,
    Cluster
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @backup_path Path.join([:code.priv_dir(:uplink), "backup"])

  def show(options \\ [cache: true, backup: true]) do
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
    backup = Keyword.get(options, :backup)

    [Clients.Instellar.endpoint(), "self"]
    |> Path.join()
    |> Req.get(headers: headers())
    |> case do
      {:ok, %{status: 200, body: %{"data" => %{"attributes" => attributes}}}} ->
        if cache do
          Cache.put(:self, attributes)
        end

        if backup do
          File.mkdir_p!(@backup_path)

          @backup_path
          |> Path.join("self.json")
          |> File.write!(Jason.encode!(attributes))
        end

        attributes

      {:ok, %{status: _, body: body}} ->
        {:error, body}

      {:error, error} ->
        path = Path.join(@backup_path, "self.json")

        if File.exists?(path) do
          path
          |> File.read!()
          |> Jason.decode!()
        else
          {:error, error}
        end
    end
  end
end
