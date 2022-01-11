defmodule Uplink.Boot do
  use Task

  alias Uplink.{
    Cache,
    Clients
  }

  alias Clients.Instellar

  def start_link(options) do
    Task.start_link(__MODULE__, :perform, [])
  end

  def perform do
    case Instellar.get_self() do
      {:ok, self} ->
        Cache.put(:self, self)

      error ->
        error
    end
  end
end
