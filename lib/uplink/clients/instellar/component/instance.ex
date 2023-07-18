defmodule Uplink.Clients.Instellar.Component.Instance do
  alias Uplink.Clients.Instellar

  def create(component_id, params) do
    [
      Instellar.endpoint(),
      "self",
      "components",
      "#{component_id}",
      "instances"
    ]
    |> Path.join()
    |> Req.post!(
      {:json, params},
      headers: Instellar.Self.headers()
    )
    |> case do
      %{status: 201, body: %{"data" => %{"attributes" => attributes}}} ->
        {:ok, attributes}

      %{status: _, body: body} ->
        {:error, body}
    end
  end
end
