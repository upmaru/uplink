defmodule Uplink.Clients.Instellar.Register do
  alias Uplink.Clients
  alias Clients.Instellar

  def perform do
    headers = Instellar.Self.headers()

    [Instellar.endpoint(), "self", "registration"]
    |> Path.join()
    |> Req.post!(json: %{}, headers: headers)
    |> case do
      %{status: status, body: %{"data" => %{"attributes" => attributes}}}
      when status in [201, 200] ->
        {:ok, attributes}

      %{status: _, body: body} ->
        {:error, body}
    end
  end
end
