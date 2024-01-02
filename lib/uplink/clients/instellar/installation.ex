defmodule Uplink.Clients.Instellar.Installation do
  alias Uplink.{
    Clients,
    Packages
  }

  alias Packages.{
    Install
  }

  alias Clients.Instellar

  def metadata(%Install{
        instellar_installation_id: instellar_installation_id,
        deployment: deployment
      }) do
    [
      Instellar.endpoint(),
      "installations",
      "#{instellar_installation_id}"
    ]
    |> Path.join()
    |> Req.get(headers: Instellar.headers(deployment.hash), max_retries: 1)
    |> case do
      {:ok, %{status: 200, body: %{"data" => %{"attributes" => attributes}}}} ->
        {:ok, attributes}

      {:ok, %{status: _, body: body}} ->
        {:error, body}

      {:error, error} ->
        {:error, error}
    end
  end
end
