defmodule Uplink.Installations.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Uplink.Installations.Router

  @opts Router.init([])

  @valid_delete_body Jason.encode!(%{
                       "actor" => %{
                         "provider" => "instellar",
                         "identifier" => "zacksiri",
                         "id" => "1"
                       },
                       "event" => %{
                         "name" => "delete"
                       }
                     })

  describe "delete installs" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_delete_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature}
    end
  end
end