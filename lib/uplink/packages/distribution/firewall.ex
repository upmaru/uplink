defmodule Uplink.Packages.Distribution.Firewall do
  alias Uplink.Clients
  alias Clients.LXD

  def allowed?(conn) do
    case LXD.network_leases() do
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
end
