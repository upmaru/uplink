defmodule Uplink.Routings do
  alias __MODULE__.Proxy

  defdelegate list_proxies(router_id),
    to: Proxy.Manager,
    as: :list
end
