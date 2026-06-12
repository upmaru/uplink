defmodule Uplink.Availability.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Secret
  alias Uplink.Availability

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  post "/resources" do
    %{
      "requirement" => requirement_params
    } = conn.body_params

    with {:ok, requirements} <-
           Availability.process_requirement(requirement_params),
         {:ok, resources} <- Availability.check!(requirements) do
      json(conn, :ok, resources)
    else
      {:error, %Ecto.Changeset{} = error} ->
        json(conn, :unprocessable_entity, handle_changeset(error))

      {:error, reason} ->
        json(conn, :service_unavailable, %{error: %{message: reason}})
    end
  end
end
