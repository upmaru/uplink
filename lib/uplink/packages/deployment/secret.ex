defmodule Uplink.Packages.Deployment.Secret do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    
  end
  
  defp config(key) do
    Application.get_env(:uplink, __MODULE__)
    |> Keyword.get(key)
  end
end