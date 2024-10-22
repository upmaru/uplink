defmodule Uplink.Monitors do
  alias Uplink.Clients.Instellar

  def index(type) do
    %{"uplink" => %{"id" => uplink_id}} = Instellar.get_self()

    "metrics-system.#{type}-uplink-#{uplink_id}-*"
  end

  def push(monitor, type, params) do
    headers = headers(monitor)
    index = index(type)

    [index, "_doc"]
    |> Path.join()
    |> Repo.post(headers: headers, json: params)
  end

  defp headers(%{"attributes" => %{"uid" => uid, "token" => token}}) do
    Base.encode64("#{uid}:#{token}")

    [
      {"authorization", "ApiKey #{token}"}
    ]
  end
end
