defmodule Uplink.Clients.Instellar.Monitor do
  alias Uplink.Clients.Instellar

  def list do
    headers = Instellar.Self.headers()

    [Instellar.endpoint(), "self", "monitors"]
    |> Path.join()
    |> Req.get(headers: headers, max_retries: 1)
    |> case do
      {:ok, %{status: 200, body: %{"data" => monitors}}} ->
        {:ok, monitors}

      {:ok, %{status: _, body: body}} ->
        {:error, body}

      {:error, error} ->
        {:error, error}
    end
  end
end
