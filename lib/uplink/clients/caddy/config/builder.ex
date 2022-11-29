defmodule Uplink.Clients.Caddy.Config.Builder do
  alias Uplink.Clients.Caddy
  alias Caddy.Admin
  
  def new do    
    %{admin: admin(), apps: apps()}
  end
  
	def admin do
    zero_ssl_api_key = Caddy.config(:zero_ssl_api_key)
    
    %{
      identity: %{
        identifiers: [""],
        issuers: [
          %{module: "zerossl", api_key: zero_ssl_api_key}
        ]
      }
    }
    |> Admin.parse()
  end
  
  def apps do
    %{
      http: %{
        servers: servers()
      }
    }
  end
  
  def servers do
    
  end
end