defmodule Uplink.Components.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Secret

  alias Uplink.Members
  alias Uplink.Components.Instance.Enqueue

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  post "/:component_id/instances" do
    %{"actor" => actor_params} = conn.body_params

    with {:ok, %Members.Actor{}} <- Members.get_or_create_actor(actor_params),
         {:ok, job} <- Enqueue.job(component_id, conn.body_params) do
      json(conn, :created, %{id: job.id})
    else
      {:error, :unprocessable_entity = error} ->
        json(conn, error, %{
          error: %{message: "invalid parameters for component instance job"}
        })
    end
  end
end
