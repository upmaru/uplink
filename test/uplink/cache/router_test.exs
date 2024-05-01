defmodule Uplink.Cache.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Uplink.Cache.Router

  @opts Router.init([])

  @valid_delete_body Jason.encode!(%{
                       "actor" => %{
                         "provider" => "instellar",
                         "identifier" => "zacksiri",
                         "id" => "1"
                       }
                     })

  describe "delete self" do
    setup do
      signature =
        :crypto.mac(:hmac, :sha256, Uplink.Secret.get(), @valid_delete_body)
        |> Base.encode16()
        |> String.downcase()

      {:ok, signature: signature}
    end

    test "can successfully delete :self", %{signature: signature} do
      conn =
        conn(:delete, "/self", @valid_delete_body)
        |> put_req_header("x-uplink-signature-256", "sha256=#{signature}")
        |> put_req_header("content-type", "application/json")
        |> Router.call(@opts)

      assert conn.status == 200
    end
  end
end
