defmodule Uplink.Components.Router do
  use Plug.Router
  use Uplink.Web

  alias Uplink.Secret

  alias Uplink.Members
  alias Uplink.Components.Instance.Provision

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :json],
    body_reader: {Uplink.Web.CacheBodyReader, :read_body, []},
    json_decoder: Jason

  plug Secret.VerificationPlug

  plug :dispatch

  post "/:component_id/instances" do
    %{
      "actor" => actor_params,
      "arguments" => argument_params,
      "variable_id" => variable_id
    } = conn.body_params

    with {:ok, %Members.Actor{}} <- Members.get_or_create_actor(actor_params),
         {:ok, job} <-
           Provision.new(%{
             component_id: component_id,
             variable_id: variable_id,
             arguments: argument_params
           })
           |> Oban.insert() do
      json(conn, :created, %{id: job.id})
    end
  end
end
