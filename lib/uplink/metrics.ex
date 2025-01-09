defmodule Uplink.Metrics do
  alias Uplink.Clients.Instellar

  defdelegate for_instances(),
    to: __MODULE__.Instance,
    as: :metrics

  def query!(%{"attributes" => attributes} = monitor, query) do
    headers = headers(monitor)
    endpoint = Map.fetch!(attributes, "endpoint")

    request = request(endpoint, headers)

    Req.post!(request, url: "/_msearch", body: query)
  end

  def query!(_, _), do: {:error, :invalid_monitor}

  def push!(%{"attributes" => attributes} = monitor, documents) do
    headers = headers(monitor)
    endpoint = Map.fetch!(attributes, "endpoint")

    request = request(endpoint, headers)

    Req.post!(request, url: "/_bulk", body: documents)
  end

  def index(type) do
    %{"uplink" => %{"id" => uplink_id}} = Instellar.get_self()

    "metrics-system.#{type}-uplink-#{uplink_id}"
  end

  def request(endpoint, headers) do
    Req.new(
      base_url: endpoint,
      connect_options: [
        protocols: [:http1],
        transport_opts: [
          verify: :verify_none
        ]
      ],
      headers: headers
    )
  end

  def headers(%{"attributes" => %{"uid" => uid, "token" => token}}) do
    encoded_token = Base.encode64("#{uid}:#{token}")

    [
      {"authorization", "ApiKey #{encoded_token}"},
      {"content-type", "application/json"}
    ]
  end
end
