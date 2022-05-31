defmodule Uplink.Clients.LXD.Profile.Manager do
  alias Uplink.{
    Clients,
    Cache
  }

  alias Clients.LXD
  alias LXD.Profile

  def list do
    Cache.get(:profiles) ||
      LXD.client()
      |> Lexdee.list_profiles(query: [recursion: 1])
      |> case do
        {:ok, %{body: profiles}} ->
          profiles =
            profiles
            |> Enum.map(fn profile ->
              Profile.parse(profile)
            end)

          Cache.put(:profiles, profiles)

          profiles

        error ->
          error
      end
  end
end
