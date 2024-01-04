defmodule Uplink.Clients.Instellar.Proxy do
  alias Uplink.Clients.Instellar

  def list(router_id) do
    headers = Instellar.Self.headers()

    [Instellar.endpoint(), "self", "routers", router_id, "proxies"]
    |> Path.join()
    |> Req.get(headers: headers, max_retries: 1)
    |> case do
      {:ok, %{status: 200, body: %{"data" => proxies}}} ->
        {:ok, proxies}

      {:ok, %{status: _, body: body}} ->
        {:error, body}

      {:error, error} ->
        {:error, error}
    end
  end
end
