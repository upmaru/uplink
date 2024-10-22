defmodule Uplink.Monitors do
  alias Uplink.Clients.Instellar

  defdelegate get_instances_metrics,
    to: __MODULE__.Instance,
    as: :metrics

  def push(%{"attributes" => attributes} = monitor, type, document) do
    headers = headers(monitor)
    index = index(type)
    endpoint = Map.fetch!(attributes, "endpoint")

    [endpoint, index, "_doc"]
    |> Path.join()
    |> Req.post(headers: headers, json: document)
  end

  defp index(type) do
    %{"uplink" => %{"id" => uplink_id}} = Instellar.get_self()

    "metrics-system.#{type}-uplink-#{uplink_id}"
  end

  defp headers(%{"attributes" => %{"uid" => uid, "token" => token}}) do
    encoded_token = Base.encode64("#{uid}:#{token}")

    [{"authorization", "ApiKey #{encoded_token}"}]
  end
end
