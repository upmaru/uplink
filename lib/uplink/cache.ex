defmodule Uplink.Cache do
  use Nebulex.Cache,
    otp_app: :uplink,
    adapter: Nebulex.Adapters.Replicated
end