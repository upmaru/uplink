defmodule Uplink.Clients.Caddy.Config do
  def get do
    [Uplink.Clients.Caddy.default_endpoint(), "config", "/"]
    |> Path.join()
    |> Req.get!()
    |> case do
      %{status: 200, body: body} ->
        {:ok, body}

      %{status: _, body: body} ->
        {:error, body}
    end
  end
  
  def load(params) do
    [Uplink.Clients.Caddy.default_endpoint(), "load"]
    |> Path.join()
    |> Req.post!({:json, params})
    |> case do
      %{status: 200, body: body} ->
        {:ok, body}
        
      %{status: _, body: body} ->
        {:error, body}
    end
  end
end
