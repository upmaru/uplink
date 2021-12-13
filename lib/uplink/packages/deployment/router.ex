defmodule Uplink.Packages.Deployment.Router do
  use Plug.Router 
  
  alias Uplink.Packages.Deployment
  
  plug Deployment.Secret
  
  post "/" do
    %{"deployment" => deployment_params} = conn.body_params
    
  end
end