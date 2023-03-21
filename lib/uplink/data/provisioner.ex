defmodule Uplink.Data.Provisioner do
  use GenServer

  require Logger

  alias Uplink.Clients.LXD

  defstruct [:mode, :status]

  @type t :: %__MODULE__{
          mode: String.t(),
          status: :ok | :error | :provisioning | nil
        }

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    config = Application.get_env(:uplink, Uplink.Data) || []
    mode = Keyword.get(config, :mode, "pro")

    send(self(), {:bootstrap, mode})

    {:ok, %__MODULE__{mode: mode}}
  end

  @impl true
  def handle_info({:bootstrap, "pro"}, state) do
    Uplink.Data.start_link([])

    {:noreply, put_in(state.status, :ok)}
  end

  def handle_info({:bootstrap, "lite"}, state) do
    db_url = Formation.Lxd.Alpine.postgresql_connection_url(scheme: "ecto")
    uri = URI.parse(db_url)

    [username, password] = String.split(uri.userinfo, ":")
    [_, database_name] = String.split(uri.path, "/")

    {:ok, conn} =
      Postgrex.start_link(
        hostname: uri.host,
        username: username,
        password: password,
        database: database_name
      )

    case Postgrex.query(conn, "SELECT 1", []) do
      {:ok, _} ->
        Application.put_env(:uplink, Uplink.Repo, url: db_url)
        GenServer.stop(conn)

        Uplink.Release.Tasks.migrate(force: true)
        Uplink.Data.start_link([])

        {:noreply, put_in(state.status, :ok)}

      {:error, _} ->
        GenServer.stop(conn)

        Logger.info("[Data.Provisioner] provisioning local postgresql ...")

        client = LXD.client()
        Formation.Lxd.Alpine.provision_postgresql(client)

        Process.send_after(self(), {:bootstrap, state.mode}, 5_000)

        {:noreply, put_in(state.status, :provisioning)}
    end
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end
end
