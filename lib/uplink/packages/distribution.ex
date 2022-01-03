defmodule Uplink.Packages.Distribution do
  use Plug.Builder

  plug :validate

  plug Plug.Static,
    at: "/",
    from: "tmp/deployments"

  plug :respond

  defp validate(conn, _opts) do
    IO.inspect(conn)
  end

  defp respond(conn, _opts), 
    do: send_resp(conn)
end
