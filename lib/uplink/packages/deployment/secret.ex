defmodule Uplink.Packages.Deployment.Secret do
  import Plug.Conn

  alias Uplink.Secret

  def init(opts), do: opts

  def call(conn, _opts) do
    secret = Secret.get()
  end
end
