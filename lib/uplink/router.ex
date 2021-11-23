defmodule Uplink.Router do
  use Plug.Router
  
  plug :match
  plug :dispatch
  plug Plug.Parsers,
    parsers: [:urldecoder, :json],
    json_decoder: Jason
    
  alias Uplink.Utils
  
  alias Uplink.Deployments
  
  post "/deployments" do
    %{"deployment" => deployment_params} = conn.body_params
    
    deployment_entry = Utils.to_struct(Deployments.Entry, deployment_params)
  end
end