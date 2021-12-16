defmodule Uplink.Web do
  def json(conn, status, response) do
    conn
    |> Plug.Conn.send_resp(status, Jason.encode!(response))
  end

  defmacro __using__(_opts) do
    quote do
      import Uplink.Web
    end
  end
end
