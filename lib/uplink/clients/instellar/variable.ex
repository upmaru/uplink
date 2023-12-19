defmodule Uplink.Clients.Instellar.Variable do
  alias Uplink.Clients
  alias Clients.Instellar

  def create(params) do
    [
      Instellar.endpoint(),
      "self",
      "variables"
    ]
    |> Path.join()
    |> Req.post!(json: params, headers: Instellar.Self.headers())
    |> case do
      %{status: 201, body: %{"data" => %{"attributes" => attributes}}} ->
        {:ok, attributes}

      %{status: _, body: body} ->
        {:error, body}
    end
  end
end
