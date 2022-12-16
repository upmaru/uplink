defmodule Uplink.Clients.Caddy.Config do
  alias Uplink.Clients.Caddy.{
    Apps,
    Admin
  }

  @mappings %{
    "admin" => {:admin, Admin},
    "apps" => {:apps, Apps}
  }

  def parse(body) do
    body
    |> Enum.map(fn {key, result} ->
      if mapping = Map.get(@mappings, key) do
        {atom_key, module} = mapping
        {atom_key, module.parse(result)}
      else
        nil
      end
    end)
    |> Enum.into(%{})
  end

  def get do
    config_path =
      [Uplink.Clients.Caddy.default_endpoint(), "config"]
      |> Path.join()

    config_path <> "/"
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
