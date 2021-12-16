defmodule Uplink.Packages.Deployment.Secret do
  import Plug.Conn

  import Uplink.Secret.Signature,
    only: [compute_signature: 1]

  use Uplink.Web

  def init(opts), do: opts

  def call(conn, _opts) do
    {:ok, body, _} = read_body(conn)

    [request_signature] = get_req_header(conn, "x-uplink-signature-256")

    signature = compute_signature(body)

    if "sha256=#{signature}" == request_signature do
      conn
    else
      conn
      |> json(:not_acceptable, %{error: %{message: "invalid signature"}})
      |> halt()
    end
  end
end
