defmodule Uplink.Installations.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Secret
  alias Uplink.Installations

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  plug Plug.Logger

  post "/:instellar_installation_id/events" do
    case conn.body_params do
      %{"event" => %{"name" => "delete"}} ->
        {:ok, job} =
          %{instellar_installation_id: instellar_installation_id}
          |> Installations.Delete.new()
          |> Oban.insert()

        json(conn, :created, %{id: job.id})

      _ ->
        json(conn, :unprocessable_entity, %{
          error: %{message: "event not supported"}
        })
    end
  end
end
