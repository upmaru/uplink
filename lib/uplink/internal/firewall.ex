defmodule Uplink.Internal.Firewall do
  alias Uplink.Clients
  alias Clients.LXD

  alias Uplink.Repo
  alias Uplink.Packages.Install

  import Ecto.Query, only: [from: 2]

  def allowed?(conn) do
    conn
    |> project_name()
    |> LXD.network_leases()
    |> case do
      leases when is_list(leases) ->
        ip_addresses =
          Enum.map(leases, fn lease ->
            lease.address
          end)

        detected_ip_address =
          conn.remote_ip
          |> :inet.ntoa()
          |> to_string()

        if detected_ip_address in ip_addresses do
          :ok
        else
          {:error, :forbidden}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp project_name(conn) do
    case conn.params do
      %{"glob" => params} ->
        conn.script_name
        |> List.first()
        |> build_from_glob(params)

      %{"instellar_installation_id" => instellar_installation_id} ->
        build_from_install(instellar_installation_id)
    end
  end

  defp build_from_glob(script_name, params)
       when script_name in ["distribution", "installs"] do
    case Enum.take(params, 3) do
      [_channel, org, package] ->
        "#{org}.#{package}"

      [instellar_installation_id, "variables"] ->
        build_from_install(instellar_installation_id)
    end
  end

  defp build_from_install(instellar_installation_id) do
    %Install{deployment: %{app: app}} =
      from(
        i in Install,
        where: i.instellar_installation_id == ^instellar_installation_id,
        limit: 1,
        order_by: [desc: :inserted_at],
        preload: [deployment: [:app]]
      )
      |> Repo.one!()

    [org, package] = String.split(app.slug, "/")

    "#{org}.#{package}"
  end
end
