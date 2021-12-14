defmodule Uplink.Secret do
  def get do
    Application.get_env(:uplink, __MODULE__)
  end
end
