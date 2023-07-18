defmodule Uplink.Clients.Instellar.Component do
  alias Uplink.Clients.Instellar

  def show(component_id) do
    [
      Instellar.endpoint(),
      "self",
      "components",
      "#{component_id}"
    ]
    |> Path.join()
    |> Req.get!(headers: Instellar.Self.headers())
    |> case do
      %{status: 200, body: %{"data" => %{"attributes" => attributes}}} ->
        {:ok, attributes}

      %{status: _, body: body} ->
        {:error, body}
    end
  end
end
