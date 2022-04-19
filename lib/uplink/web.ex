defmodule Uplink.Web do
  import Plug.Conn

  def json(conn, status, response) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(status, Jason.encode!(%{data: response}))
  end

  defmacro __using__(_opts) do
    quote do
      import Uplink.Web
    end
  end

  defmodule Certificate do
    @key_size 2048
    @default_name "uplink"
    @default_hostnames ["localhost"]

    def generate do
      private_key = X509.PrivateKey.new_rsa(@key_size)

      certificate =
        X509.Certificate.self_signed(
          private_key,
          "/CN=#{@default_name}",
          template: :server,
          extensions: [
            subject_alt_names:
              X509.Certificate.Extension.subject_alt_name(@default_hostnames)
          ]
        )

      %{
        key: X509.PrivateKey.to_der(private_key),
        cert: X509.Certificate.to_der(certificate)
      }
    end
  end
end
