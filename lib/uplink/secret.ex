defmodule Uplink.Secret do
  def get do
    Application.get_env(:uplink, __MODULE__)
  end

  defmodule Signature do
    def compute_signature(content) do
      secret = Uplink.Secret.get()

      :crypto.mac(:hmac, :sha256, secret, content)
      |> Base.encode16()
      |> String.downcase()
    end
  end

  defmodule VerificationPlug do
    import Plug.Conn

    import Uplink.Secret.Signature,
      only: [compute_signature: 1]

    use Uplink.Web

    def init(opts), do: opts

    def call(conn, _opts) do
      case get_req_header(conn, "x-uplink-signature-256") do
        [request_signature] ->
          signature = compute_signature(conn.assigns.raw_body)

          if "sha256=#{signature}" == request_signature do
            conn
          else
            conn
            |> json(:not_acceptable, %{error: %{message: "invalid signature"}})
            |> halt()
          end

        [] ->
          conn
          |> json(:unauthorized, %{error: %{message: "unauthorized"}})
          |> halt()
      end
    end
  end
end
