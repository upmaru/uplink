defmodule Uplink.Packages.Deployment.Secret do
  import Plug.Conn

  alias Uplink.Secret

  import Uplink.Secret.Signature, only: [compute_signature: 1]

  def init(opts), do: opts

  def call(conn, _opts) do
    secret = Secret.get()

    {:ok, body, _} = read_body(conn)

    [request_signature] = get_req_header(conn, "x-uplink-signature-256")

    signature = compute_signature(body)

    if "sha256=#{signature}" == request_signature do
      conn
    else
      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(:not_acceptable, render_error())
      |> halt()
    end
  end

  defp render_error,
    do: Jason.encode!(%{data: %{errors: %{detail: "invalid signature"}}})
end
