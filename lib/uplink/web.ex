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
end
