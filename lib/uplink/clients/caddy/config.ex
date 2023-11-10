defmodule Uplink.Clients.Caddy.Config do
  alias Uplink.Clients.Caddy

  alias Caddy.{
    Apps,
    Admin,
    Storage
  }

  @mappings %{
    "admin" => {:admin, Admin},
    "apps" => {:apps, Apps},
    "storage" => {:storage, Storage}
  }

  def parse(body) do
    body
    |> Enum.map(fn {key, result} ->
      if mapping = Map.get(@mappings, key) do
        {atom_key, module} = mapping
        {atom_key, module.parse(result)}
      else
        {String.to_existing_atom(key), result}
      end
    end)
    |> Enum.into(%{})
  end

  def get do
    config_path =
      [Caddy.config(:endpoint), "config"]
      |> Path.join()

    (config_path <> "/")
    |> Req.get!()
    |> case do
      %{status: 200, body: body} ->
        {:ok, body}

      %{status: _, body: body} ->
        {:error, body}
    end
  end

  def load(params) do
    [Caddy.config(:endpoint), "load"]
    |> Path.join()
    |> Req.post!(json: params, receive_timeout: 60_000)
    |> case do
      %{status: 200, body: body} ->
        {:ok, body}

      %{status: _, body: body} ->
        {:error, body}
    end
  end
end
