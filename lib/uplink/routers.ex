defmodule Uplink.Routers do
  @moduledoc """
  The routers context is not to be confused with Uplink.Router.

  Routers correlates with Instellar.Uplinks.Router context
  """

  alias __MODULE__.Proxy

  defdelegate list_proxies(router_id),
    to: Proxy.Manager,
    as: :list
end
