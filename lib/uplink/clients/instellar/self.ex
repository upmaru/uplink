defmodule Uplink.Clients.Instellar.Self do
  alias Uplink.{
    Cache,
    Clients,
    Cluster
  }

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  @backup_path "backup/self.json"

  require Logger

  def show(options \\ [cache: true, backup: true]) do
    backup = Keyword.get(options, :backup)

    Cache.get(:self)
    |> case do
      nil ->
        fetch(options)

      %{"credential" => _credential} = response ->
        if backup and not File.exists?(@backup_path) do
          create_backup(response)
        end

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
          create_backup(attributes)
        end

        attributes

      {:ok, %{status: _, body: body}} ->
        {:error, body}

      {:error, error} ->
        if File.exists?(@backup_path) do
          Logger.info("[Instellar.Self] fetching from backup...")

          attributes =
            @backup_path
            |> File.read!()
            |> Jason.decode!()

          Cache.put_new(:self, attributes)

          attributes
        else
          {:error, error}
        end
    end
  end

  defp create_backup(attributes) do
    Logger.info("[Instellar.Self] creating backup...")

    File.mkdir_p!(Path.dirname(@backup_path))

    File.write!(@backup_path, Jason.encode!(attributes))
  end
end
